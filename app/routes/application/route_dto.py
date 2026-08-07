from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class CreateRouteRequest(BaseModel):
    name: str
    description: Optional[str] = None
    author_id: int
    geojson: dict
    distance_km: float
    duration_minutes: int


class CreateRouteFromRideRequest(BaseModel):
    ride_id: int
    name: str
    description: Optional[str] = None


class RouteResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    author_id: int
    geojson: dict
    distance_km: float
    duration_minutes: int
    created_at: datetime
    times_ridden: int

    model_config = ConfigDict(from_attributes=True)
