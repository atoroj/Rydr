from dataclasses import dataclass
from datetime import datetime


@dataclass
class Meetup:
    id: int | None
    organizer_id: int
    title: str
    description: str | None
    location_name: str | None
    location_lat: float
    location_lng: float
    scheduled_at: datetime
    max_participants: int | None  # None = sin límite
    is_private: bool  # True = solo visible/apuntable para los Riders del organizador
    created_at: datetime


@dataclass
class LiveLocation:
    """Última posición compartida por un participante mientras la quedada
    está en marcha — no se guarda historial, solo el punto más reciente."""
    user_id: int
    lat: float
    lng: float
    updated_at: datetime
