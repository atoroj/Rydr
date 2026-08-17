from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, ConfigDict


class StartRideRequest(BaseModel):
    rider_id: int
    motorbike_id: int


class AddTrackPointRequest(BaseModel):
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    speed: Optional[float] = None
    timestamp: datetime


class AddTrackPointsBatchRequest(BaseModel):
    """Para reenviar de golpe los puntos que se quedaron en cola en el
    móvil por falta de cobertura — en vez de uno a uno, que tras una
    desconexión larga puede ser cientos de peticiones sueltas."""
    points: List[AddTrackPointRequest]


class AddTrackPointsBatchResponse(BaseModel):
    created: int


class TrackPointResponse(BaseModel):
    id: int
    ride_id: int
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    speed: Optional[float] = None
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)


class RideResponse(BaseModel):
    id: int
    rider_id: int
    motorbike_id: int
    started_at: datetime
    finished_at: Optional[datetime] = None
    is_public: bool
    track_points: List[TrackPointResponse] = []

    model_config = ConfigDict(from_attributes=True)
