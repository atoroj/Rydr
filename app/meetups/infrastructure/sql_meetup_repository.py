from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

from app.meetups.domain.meetup import Meetup, LiveLocation
from app.meetups.domain.meetup_repository import MeetupRepository
from app.meetups.infrastructure.meetup_model import MeetupModel, MeetupParticipantModel


class SqlAlchemyMeetupRepository(MeetupRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_domain(self, m: MeetupModel) -> Meetup:
        return Meetup(
            id=m.id, organizer_id=m.organizer_id, title=m.title, description=m.description,
            location_name=m.location_name, location_lat=m.location_lat, location_lng=m.location_lng,
            scheduled_at=m.scheduled_at, max_participants=m.max_participants,
            is_private=bool(m.is_private), created_at=m.created_at,
        )

    def save(self, meetup: Meetup) -> Meetup:
        m = MeetupModel(
            organizer_id=meetup.organizer_id, title=meetup.title, description=meetup.description,
            location_name=meetup.location_name, location_lat=meetup.location_lat,
            location_lng=meetup.location_lng, scheduled_at=meetup.scheduled_at,
            max_participants=meetup.max_participants, is_private=meetup.is_private,
            created_at=meetup.created_at,
        )
        self.db.add(m)
        self.db.commit()
        self.db.refresh(m)
        return self._to_domain(m)

    def get_by_id(self, meetup_id: int) -> Optional[Meetup]:
        m = self.db.query(MeetupModel).filter(MeetupModel.id == meetup_id).first()
        return self._to_domain(m) if m else None

    def update(self, meetup_id: int, organizer_id: int, **fields) -> Meetup:
        m = self.db.query(MeetupModel).filter(
            MeetupModel.id == meetup_id, MeetupModel.organizer_id == organizer_id
        ).first()
        if m is None:
            raise ValueError("Quedada no encontrada para este organizador")
        for key, value in fields.items():
            if value is not None:
                setattr(m, key, value)
        self.db.commit()
        self.db.refresh(m)
        return self._to_domain(m)

    def delete(self, meetup_id: int, organizer_id: int) -> None:
        m = self.db.query(MeetupModel).filter(
            MeetupModel.id == meetup_id, MeetupModel.organizer_id == organizer_id
        ).first()
        if m is None:
            raise ValueError("Quedada no encontrada para este organizador")
        self.db.query(MeetupParticipantModel).filter(MeetupParticipantModel.meetup_id == meetup_id).delete()
        self.db.delete(m)
        self.db.commit()

    def list_upcoming(self) -> List[Meetup]:
        rows = self.db.query(MeetupModel).filter(
            MeetupModel.scheduled_at >= datetime.now()
        ).order_by(MeetupModel.scheduled_at.asc()).all()
        return [self._to_domain(r) for r in rows]

    def list_by_organizer(self, organizer_id: int) -> List[Meetup]:
        rows = self.db.query(MeetupModel).filter(MeetupModel.organizer_id == organizer_id).all()
        return [self._to_domain(r) for r in rows]

    def list_joined_by(self, user_id: int) -> List[Meetup]:
        meetup_ids = [
            p.meetup_id for p in
            self.db.query(MeetupParticipantModel).filter(MeetupParticipantModel.user_id == user_id).all()
        ]
        if not meetup_ids:
            return []
        rows = self.db.query(MeetupModel).filter(MeetupModel.id.in_(meetup_ids)).all()
        return [self._to_domain(r) for r in rows]

    # ── Participantes ────────────────────────────────────────────────────

    def add_participant(self, meetup_id: int, user_id: int) -> None:
        if self.is_participant(meetup_id, user_id):
            return
        self.db.add(MeetupParticipantModel(meetup_id=meetup_id, user_id=user_id, joined_at=datetime.now()))
        self.db.commit()

    def remove_participant(self, meetup_id: int, user_id: int) -> None:
        self.db.query(MeetupParticipantModel).filter(
            MeetupParticipantModel.meetup_id == meetup_id, MeetupParticipantModel.user_id == user_id
        ).delete()
        self.db.commit()

    def is_participant(self, meetup_id: int, user_id: int) -> bool:
        return self.db.query(MeetupParticipantModel).filter(
            MeetupParticipantModel.meetup_id == meetup_id, MeetupParticipantModel.user_id == user_id
        ).first() is not None

    def count_participants(self, meetup_id: int) -> int:
        return self.db.query(MeetupParticipantModel).filter(
            MeetupParticipantModel.meetup_id == meetup_id
        ).count()

    def list_participant_ids(self, meetup_id: int) -> List[int]:
        rows = self.db.query(MeetupParticipantModel).filter(MeetupParticipantModel.meetup_id == meetup_id).all()
        return [r.user_id for r in rows]

    # ── Ubicación en vivo ────────────────────────────────────────────────

    def update_location(self, meetup_id: int, user_id: int, lat: float, lng: float, at: datetime) -> None:
        p = self.db.query(MeetupParticipantModel).filter(
            MeetupParticipantModel.meetup_id == meetup_id, MeetupParticipantModel.user_id == user_id
        ).first()
        if p is None:
            return
        p.last_lat = lat
        p.last_lng = lng
        p.last_location_at = at
        self.db.commit()

    def list_live_locations(self, meetup_id: int, since: datetime) -> List[LiveLocation]:
        rows = self.db.query(MeetupParticipantModel).filter(
            MeetupParticipantModel.meetup_id == meetup_id,
            MeetupParticipantModel.last_location_at.isnot(None),
            MeetupParticipantModel.last_location_at >= since,
        ).all()
        return [
            LiveLocation(user_id=r.user_id, lat=r.last_lat, lng=r.last_lng, updated_at=r.last_location_at)
            for r in rows
        ]
