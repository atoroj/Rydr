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


class UpdateMeetupRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    scheduled_at: Optional[datetime] = None
    max_participants: Optional[int] = None
    is_private: Optional[bool] = None


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
    location_name: Optional[str] = None
    location_lat: float
    location_lng: float
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
