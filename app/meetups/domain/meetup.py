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
    # Ubicación oculta hasta que el organizador la revela — ortogonal a
    # `is_private` (que controla quién ve que la quedada EXISTE; esto
    # controla quién ve el PUNTO EXACTO). Caso de uso: una quedada
    # anunciada públicamente a mucha gente, pero solo quien se apunte de
    # verdad debe saber dónde es.
    location_hidden: bool = False
    # Texto libre visible siempre, apuntado o no, mientras la ubicación
    # exacta esté oculta ("Sierra de Guadarrama", "Cerca de Madrid"...).
    approximate_area: str | None = None
    # Lo activa el organizador con una acción explícita — no hay vuelta
    # atrás (no se vuelve a ocultar una vez revelada).
    location_revealed: bool = False


@dataclass
class LiveLocation:
    """Última posición compartida por un participante mientras la quedada
    está en marcha — no se guarda historial, solo el punto más reciente."""
    user_id: int
    lat: float
    lng: float
    updated_at: datetime
