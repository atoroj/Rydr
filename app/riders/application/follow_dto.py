from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class MotorbikeSummary(BaseModel):
    id: int
    brand: str
    model: str
    alias: Optional[str] = None
    photo_url: Optional[str] = None
    year: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class RouteSummaryResponse(BaseModel):
    id: int
    name: str
    geojson: dict
    distance_km: float
    duration_minutes: int
    cover_image_url: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RiderSummaryResponse(BaseModel):
    id: int
    username: str
    avatar_url: Optional[str] = None
    is_private: bool
    follow_status: str  # self | not_following | pending | following
    current_motorbike: Optional[MotorbikeSummary] = None


class FollowRequestResponse(BaseModel):
    id: int  # id de la solicitud (follow.id) — se usa para aceptar/rechazar
    from_user: RiderSummaryResponse
    created_at: datetime


class FeedItemResponse(BaseModel):
    author: RiderSummaryResponse
    route: RouteSummaryResponse


class RiderProfileResponse(BaseModel):
    id: int
    username: str
    avatar_url: Optional[str] = None
    is_private: bool
    follow_status: str
    is_visible: bool  # False → privado y el viewer no le sigue: solo cabecera
    current_motorbike: Optional[MotorbikeSummary] = None
    recent_routes: List[RouteSummaryResponse] = []
