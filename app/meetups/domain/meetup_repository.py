from abc import ABC, abstractmethod
from datetime import datetime
from typing import List, Optional

from app.meetups.domain.meetup import Meetup, LiveLocation


class MeetupRepository(ABC):
    @abstractmethod
    def save(self, meetup: Meetup) -> Meetup:
        pass

    @abstractmethod
    def get_by_id(self, meetup_id: int) -> Optional[Meetup]:
        pass

    @abstractmethod
    def update(self, meetup_id: int, organizer_id: int, **fields) -> Meetup:
        """Actualiza los campos no-`None`. Solo el organizador puede editar."""
        pass

    @abstractmethod
    def delete(self, meetup_id: int, organizer_id: int) -> None:
        pass

    @abstractmethod
    def list_upcoming(self) -> List[Meetup]:
        """Todas las próximas (`scheduled_at` en el futuro), públicas y
        privadas — el filtrado de visibilidad lo hace el servicio."""
        pass

    @abstractmethod
    def list_by_organizer(self, organizer_id: int) -> List[Meetup]:
        pass

    @abstractmethod
    def list_joined_by(self, user_id: int) -> List[Meetup]:
        pass

    # ── Participantes ────────────────────────────────────────────────────

    @abstractmethod
    def add_participant(self, meetup_id: int, user_id: int) -> None:
        """Idempotente: si ya está apuntado, no hace nada."""
        pass

    @abstractmethod
    def remove_participant(self, meetup_id: int, user_id: int) -> None:
        pass

    @abstractmethod
    def is_participant(self, meetup_id: int, user_id: int) -> bool:
        pass

    @abstractmethod
    def count_participants(self, meetup_id: int) -> int:
        pass

    @abstractmethod
    def list_participant_ids(self, meetup_id: int) -> List[int]:
        pass

    # ── Ubicación en vivo ────────────────────────────────────────────────

    @abstractmethod
    def update_location(self, meetup_id: int, user_id: int, lat: float, lng: float, at: datetime) -> None:
        """No-op si `user_id` no está apuntado a la quedada — lo decide el
        servicio antes de llamar aquí."""
        pass

    @abstractmethod
    def list_live_locations(self, meetup_id: int, since: datetime) -> List[LiveLocation]:
        """Solo participantes con `last_location_at >= since` — así quien
        deja de compartir desaparece solo, sin un "dejar de compartir"
        explícito."""
        pass
