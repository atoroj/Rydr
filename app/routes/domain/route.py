from dataclasses import dataclass
from datetime import datetime


@dataclass
class Route:
    id: int | None
    name: str
    description: str | None
    author_id: int
    geojson: dict  # GeoJSON LineString: {"type": "LineString", "coordinates": [[lon, lat], ...]}
    distance_km: float
    duration_minutes: int
    created_at: datetime
    times_ridden: int
    cover_image_url: str | None = None
