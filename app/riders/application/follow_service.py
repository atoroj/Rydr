from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

from app.motorbikes.domain.motorbike import Motorbike
from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy
from app.riders.domain.follow import Follow, FollowStatus
from app.riders.domain.follow_repository import FollowRepository
from app.routes.domain.route import Route
from app.routes.domain.route_repository import RouteRepository
from app.shared.errors import NotFoundError
from app.users.domain.user import User
from app.users.domain.user_repository import UserRepository

RECENT_ROUTES_LIMIT = 10
FEED_LIMIT = 30


@dataclass
class RiderProfile:
    user: User
    follow_status: str  # "self" | "not_following" | "pending" | "following"
    is_visible: bool  # False si es privado y el viewer no le sigue: solo cabecera
    current_motorbike: Optional[Motorbike]
    recent_routes: List[Route]


@dataclass
class FeedItem:
    author: User
    route: Route


class FollowService:
    """Orquesta Riders (follow) junto con Users/Motorbikes/Routes: el perfil
    social de un rider combina datos de los cuatro módulos, así que este
    servicio de aplicación coordina varios repositorios — igual que
    RouteService ya coordina RideService para "crear ruta desde ride"."""

    def __init__(
        self,
        follow_repo: FollowRepository,
        user_repo: UserRepository,
        motorbike_repo: MotorbikeRepostiroy,
        route_repo: RouteRepository,
    ):
        self.follow_repo = follow_repo
        self.user_repo = user_repo
        self.motorbike_repo = motorbike_repo
        self.route_repo = route_repo

    # ── Relación de follow ────────────────────────────────────────────────

    def follow(self, follower_id: int, target_id: int) -> Follow:
        if follower_id == target_id:
            raise ValueError("No puedes seguirte a ti mismo")
        target = self.user_repo.get_by_id(target_id)
        if target is None:
            raise NotFoundError("Usuario no encontrado")

        existing = self.follow_repo.get_between(follower_id, target_id)
        if existing is not None:
            return existing  # idempotente: ya sigues o ya está pendiente

        # Cuenta pública → follow instantáneo. Cuenta privada → solicitud
        # pendiente hasta que el destinatario la acepte.
        new_status = FollowStatus.PENDING if target.is_private else FollowStatus.ACCEPTED
        return self.follow_repo.create(
            Follow(id=None, follower_id=follower_id, followee_id=target_id,
                   status=new_status, created_at=datetime.now())
        )

    def unfollow(self, follower_id: int, target_id: int) -> None:
        existing = self.follow_repo.get_between(follower_id, target_id)
        if existing is not None:
            self.follow_repo.delete(existing.id)

    def accept(self, request_id: int, current_user_id: int) -> Follow:
        request = self.follow_repo.get_by_id(request_id)
        if request is None:
            raise NotFoundError("Solicitud no encontrada")
        if request.followee_id != current_user_id:
            raise PermissionError("No puedes aceptar una solicitud que no es tuya")
        return self.follow_repo.update_status(request_id, FollowStatus.ACCEPTED)

    def reject(self, request_id: int, current_user_id: int) -> None:
        request = self.follow_repo.get_by_id(request_id)
        if request is None:
            raise NotFoundError("Solicitud no encontrada")
        if request.followee_id != current_user_id:
            raise PermissionError("No puedes rechazar una solicitud que no es tuya")
        self.follow_repo.delete(request_id)

    # ── Listados ─────────────────────────────────────────────────────────

    def list_following(self, user_id: int) -> List[Follow]:
        return self.follow_repo.list_following(user_id, FollowStatus.ACCEPTED)

    def list_followers(self, user_id: int) -> List[Follow]:
        return self.follow_repo.list_followers(user_id, FollowStatus.ACCEPTED)

    def list_pending_requests(self, user_id: int) -> List[Follow]:
        return self.follow_repo.list_pending_incoming(user_id)

    def search(self, query: str, viewer_id: int) -> List[User]:
        return [u for u in self.user_repo.search_by_username(query) if u.id != viewer_id]

    # ── Perfil social ────────────────────────────────────────────────────

    def follow_status_between(self, viewer_id: int, target_id: int) -> str:
        if viewer_id == target_id:
            return "self"
        existing = self.follow_repo.get_between(viewer_id, target_id)
        if existing is None:
            return "not_following"
        return "following" if existing.status == FollowStatus.ACCEPTED else "pending"

    def get_current_motorbike(self, user_id: int) -> Optional[Motorbike]:
        motorbikes = self.motorbike_repo.get_all_by_user_id(user_id)
        return next((m for m in motorbikes if m.is_current), None)

    def get_rider_profile(self, target_id: int, viewer_id: int) -> RiderProfile:
        target = self.user_repo.get_by_id(target_id)
        if target is None:
            raise NotFoundError("Usuario no encontrado")

        status = self.follow_status_between(viewer_id, target_id)
        can_view_private_content = status in ("self", "following")
        is_visible = (not target.is_private) or can_view_private_content

        routes: List[Route] = []
        if is_visible:
            all_routes = self.route_repo.get_all_by_author(target_id)
            routes = sorted(all_routes, key=lambda r: r.created_at, reverse=True)[:RECENT_ROUTES_LIMIT]

        return RiderProfile(
            user=target,
            follow_status=status,
            is_visible=is_visible,
            current_motorbike=self.get_current_motorbike(target_id),
            recent_routes=routes,
        )

    def get_activity_feed(self, user_id: int, limit: int = FEED_LIMIT) -> List[FeedItem]:
        """Rutas publicadas por la gente a la que sigues, más recientes
        primero — la portada de la app (spec: "feed de actividad de mis
        amigos riders, las rutas que han realizado")."""
        following = self.follow_repo.list_following(user_id, FollowStatus.ACCEPTED)

        items: List[FeedItem] = []
        for f in following:
            author = self.user_repo.get_by_id(f.followee_id)
            if author is None:
                continue
            for route in self.route_repo.get_all_by_author(f.followee_id):
                items.append(FeedItem(author=author, route=route))

        items.sort(key=lambda i: i.route.created_at, reverse=True)
        return items[:limit]
