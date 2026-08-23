from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Optional

from app.meetups.domain.meetup import Meetup, LiveLocation
from app.meetups.domain.meetup_repository import MeetupRepository
from app.riders.domain.follow_repository import FollowRepository
from app.riders.domain.follow import FollowStatus
from app.shared.errors import NotFoundError
from app.users.domain.user import User
from app.users.domain.user_repository import UserRepository


@dataclass
class MeetupView:
    meetup: Meetup
    organizer: User
    participant_count: int
    is_joined: bool
    is_organizer: bool
    # Si el punto exacto (`location_lat`/`lng`/`location_name`) debe
    # mandarse a quien mira, o quedarse oculto tras `approximate_area`.
    location_visible: bool


@dataclass
class LiveLocationView:
    user: User
    location: LiveLocation


class MeetupService:
    """Quedadas: organizar rutas en grupo. Privada = solo visible/apuntable
    para quien sigue al organizador (mismo modelo de "amigos" que Riders);
    pública = cualquiera puede verla y apuntarse. Coordina Meetups con
    Users (datos del organizador) y Riders (visibilidad "para amigos")."""

    # Un participante que deja de mandar ubicación (cierra la app, apaga el
    # GPS, termina la ruta) desaparece solo del mapa pasado este tiempo —
    # sin necesitar una acción explícita de "dejar de compartir".
    LIVE_LOCATION_WINDOW = timedelta(minutes=3)

    def __init__(self, meetup_repo: MeetupRepository, user_repo: UserRepository, follow_repo: FollowRepository):
        self.meetup_repo = meetup_repo
        self.user_repo = user_repo
        self.follow_repo = follow_repo

    def create(
        self, organizer_id: int, title: str, description: Optional[str], location_name: Optional[str],
        location_lat: float, location_lng: float, scheduled_at: datetime,
        max_participants: Optional[int], is_private: bool,
        location_hidden: bool = False, approximate_area: Optional[str] = None,
    ) -> Meetup:
        meetup = Meetup(
            id=None, organizer_id=organizer_id, title=title, description=description,
            location_name=location_name, location_lat=location_lat, location_lng=location_lng,
            scheduled_at=scheduled_at, max_participants=max_participants, is_private=is_private,
            created_at=datetime.now(), location_hidden=location_hidden, approximate_area=approximate_area,
        )
        saved = self.meetup_repo.save(meetup)
        # El organizador cuenta como el primer participante.
        self.meetup_repo.add_participant(saved.id, organizer_id)
        return saved

    def update(self, meetup_id: int, organizer_id: int, **fields) -> Meetup:
        return self.meetup_repo.update(meetup_id, organizer_id, **fields)

    def reveal_location(self, meetup_id: int, organizer_id: int) -> None:
        meetup = self._get_or_raise(meetup_id)
        if meetup.organizer_id != organizer_id:
            raise PermissionError("Solo el organizador puede revelar la ubicación")
        self.meetup_repo.update(meetup_id, organizer_id, location_revealed=True)

    def delete(self, meetup_id: int, organizer_id: int) -> None:
        self.meetup_repo.delete(meetup_id, organizer_id)

    def join(self, meetup_id: int, user_id: int) -> None:
        meetup = self._get_or_raise(meetup_id)
        if not self._can_view(meetup, user_id):
            raise PermissionError("Esta quedada es privada")
        if self.meetup_repo.is_participant(meetup_id, user_id):
            return
        if meetup.max_participants is not None:
            if self.meetup_repo.count_participants(meetup_id) >= meetup.max_participants:
                raise ValueError("La quedada ya está completa")
        self.meetup_repo.add_participant(meetup_id, user_id)

    def leave(self, meetup_id: int, user_id: int) -> None:
        meetup = self._get_or_raise(meetup_id)
        if meetup.organizer_id == user_id:
            raise ValueError("El organizador no puede salir de su propia quedada — bórrala si no se va a hacer")
        self.meetup_repo.remove_participant(meetup_id, user_id)

    def get_participants(self, meetup_id: int) -> List[User]:
        return [u for u in (self.user_repo.get_by_id(uid) for uid in self.meetup_repo.list_participant_ids(meetup_id)) if u]

    def update_location(self, meetup_id: int, user_id: int, lat: float, lng: float) -> None:
        if not self.meetup_repo.is_participant(meetup_id, user_id):
            raise PermissionError("Solo los apuntados a la quedada pueden compartir su ubicación")
        self.meetup_repo.update_location(meetup_id, user_id, lat, lng, datetime.now())

    def list_live_locations(self, meetup_id: int, viewer_id: int) -> List[LiveLocationView]:
        meetup = self._get_or_raise(meetup_id)
        if not self._can_view(meetup, viewer_id):
            raise PermissionError("Esta quedada es privada")
        since = datetime.now() - self.LIVE_LOCATION_WINDOW
        locations = self.meetup_repo.list_live_locations(meetup_id, since)
        views = []
        for loc in locations:
            user = self.user_repo.get_by_id(loc.user_id)
            if user:
                views.append(LiveLocationView(user=user, location=loc))
        return views

    def get_view(self, meetup_id: int, viewer_id: int) -> MeetupView:
        meetup = self._get_or_raise(meetup_id)
        if not self._can_view(meetup, viewer_id):
            raise PermissionError("Esta quedada es privada")
        return self._to_view(meetup, viewer_id)

    def list_discover(self, viewer_id: int) -> List[MeetupView]:
        """Próximas quedadas visibles: públicas + privadas de gente a la
        que sigues + las tuyas propias."""
        visible = [m for m in self.meetup_repo.list_upcoming() if self._can_view(m, viewer_id)]
        return [self._to_view(m, viewer_id) for m in visible]

    def list_mine(self, viewer_id: int) -> List[MeetupView]:
        """Las que organizas o a las que te has apuntado."""
        organized = self.meetup_repo.list_by_organizer(viewer_id)
        joined = self.meetup_repo.list_joined_by(viewer_id)
        by_id = {m.id: m for m in organized + joined}
        ordered = sorted(by_id.values(), key=lambda m: m.scheduled_at)
        return [self._to_view(m, viewer_id) for m in ordered]

    # ── Privado ──────────────────────────────────────────────────────────

    def _get_or_raise(self, meetup_id: int) -> Meetup:
        meetup = self.meetup_repo.get_by_id(meetup_id)
        if meetup is None:
            raise NotFoundError("Quedada no encontrada")
        return meetup

    def _can_view(self, meetup: Meetup, viewer_id: int) -> bool:
        if not meetup.is_private:
            return True
        if meetup.organizer_id == viewer_id:
            return True
        following_ids = {f.followee_id for f in self.follow_repo.list_following(viewer_id, FollowStatus.ACCEPTED)}
        return meetup.organizer_id in following_ids

    def _to_view(self, meetup: Meetup, viewer_id: int) -> MeetupView:
        organizer = self.user_repo.get_by_id(meetup.organizer_id)
        is_joined = self.meetup_repo.is_participant(meetup.id, viewer_id)
        is_organizer = meetup.organizer_id == viewer_id
        # El organizador siempre ve el punto exacto (es el suyo); el resto
        # solo si la quedada no oculta la ubicación, o si están apuntados
        # Y el organizador ya la ha revelado.
        location_visible = (
            not meetup.location_hidden or is_organizer or (is_joined and meetup.location_revealed)
        )
        return MeetupView(
            meetup=meetup,
            organizer=organizer,
            participant_count=self.meetup_repo.count_participants(meetup.id),
            is_joined=is_joined,
            is_organizer=is_organizer,
            location_visible=location_visible,
        )
