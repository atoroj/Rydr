from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class CreateMeetupRequest(BaseModel):
    title: str
    description: Optional[str] = None
    location_name: Optional[str] = None
    location_lat: float
    location_lng: float
    scheduled_at: datetime
    max_participants: Optional[int] = None
    is_private: bool = False
    # Ubicación oculta hasta que el organizador la revele — ver
    # `Meetup.location_hidden` en el dominio.
    location_hidden: bool = False
    approximate_area: Optional[str] = None


class UpdateMeetupRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    scheduled_at: Optional[datetime] = None
    max_participants: Optional[int] = None
    is_private: Optional[bool] = None
    location_hidden: Optional[bool] = None
    approximate_area: Optional[str] = None
    # También editable aquí (además del endpoint de acción dedicado
    # `/reveal-location`) para poder revelarla desde el mismo formulario
    # de editar quedada.
    location_revealed: Optional[bool] = None


class MeetupOrganizerResponse(BaseModel):
    id: int
    username: str
    avatar_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class MeetupResponse(BaseModel):
    id: int
    organizer: MeetupOrganizerResponse
    title: str
    description: Optional[str] = None
    # `None` cuando la ubicación está oculta para quien mira (no apuntado,
    # o apuntado pero el organizador aún no la ha revelado) — nunca se
    # manda el dato real a quien no debe verlo, esto no es solo un filtro
    # de UI. Ver `MeetupService._to_view`.
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    approximate_area: Optional[str] = None
    location_hidden: bool
    location_revealed: bool
    scheduled_at: datetime
    max_participants: Optional[int] = None
    participant_count: int
    is_private: bool
    is_joined: bool
    is_organizer: bool
    created_at: datetime


class ParticipantResponse(BaseModel):
    id: int
    username: str
    avatar_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class UpdateLocationRequest(BaseModel):
    lat: float
    lng: float


class LiveLocationResponse(BaseModel):
    user_id: int
    username: str
    avatar_url: Optional[str] = None
    lat: float
    lng: float
    updated_at: datetime
