from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class TrackPoint:
    id: int | None
    ride_id: int | None
    latitude: float
    longitude: float
    altitude: float | None
    speed: float | None  # km/h
    timestamp: datetime
    # Primer punto de un tramo nuevo tras una pausa — ver `TrackPointModel`.
    is_segment_start: bool = False


@dataclass
class Ride:
    id: int | None
    rider_id: int
    motorbike_id: int
    started_at: datetime
    finished_at: datetime | None
    is_public: bool
    track_points: list[TrackPoint] = field(default_factory=list)
