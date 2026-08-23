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
    # Punto de partida — primer punto del geojson, calculado una vez al
    # crear la ruta (ver `RouteService.create_route`/`create_route_from_ride`
    # y `app/shared/geo.py:extract_start_point`). `None` si el geojson no
    # trae coordenadas. Para el feed "cerca de ti"
    # (`FollowService.get_nearby_feed`) — sin esto, habría que parsear el
    # geojson entero en cada consulta.
    start_lat: float | None = None
    start_lng: float | None = None
