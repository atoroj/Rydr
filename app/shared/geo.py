import math


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def total_distance_km(points: list[tuple[float, float]]) -> float:
    if len(points) < 2:
        return 0.0
    return sum(
        haversine_km(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1])
        for i in range(len(points) - 1)
    )


def split_into_segments(points_with_flags: list[tuple[float, float, bool]]) -> list[list[tuple[float, float]]]:
    """Trocea una lista de (lat, lon, is_segment_start) en sub-listas de
    (lat, lon) — un corte nuevo cada vez que `is_segment_start` es True,
    salvo en el primer punto (que no cuenta como corte: ya es el arranque
    del primer tramo). Usado para no conectar con una línea recta —ni
    contar como distancia recorrida— el hueco que deja una pausa."""
    segments: list[list[tuple[float, float]]] = []
    for index, (lat, lon, is_segment_start) in enumerate(points_with_flags):
        if index == 0 or is_segment_start:
            segments.append([])
        segments[-1].append((lat, lon))
    return segments


def total_distance_km_by_segments(points_with_flags: list[tuple[float, float, bool]]) -> float:
    """Igual que `total_distance_km`, pero sin sumar el salto entre el
    último punto de un tramo y el primero del siguiente."""
    return sum(total_distance_km(segment) for segment in split_into_segments(points_with_flags))


def extract_start_point(geojson: dict) -> tuple[float, float] | None:
    """Primer punto (lat, lon) del trazado — `LineString` o
    `MultiLineString` (el primer punto del primer tramo). `None` si el
    geojson no trae coordenadas. Usado para guardar `Route.start_lat`/
    `start_lng` al crear una ruta (ver `RouteService`), así el feed
    "cerca de ti" no tiene que parsear el geojson entero en cada
    consulta — las coordenadas de GeoJSON van en orden [lon, lat]."""
    coordinates = geojson.get("coordinates")
    if not coordinates:
        return None
    first = coordinates[0]
    # `LineString`: coordinates = [[lon, lat], ...] → first = [lon, lat].
    # `MultiLineString`: coordinates = [[[lon, lat], ...], ...] → first
    # tramo = [[lon, lat], ...], su primer punto = first[0].
    if geojson.get("type") == "MultiLineString":
        if not first:
            return None
        first = first[0]
    lon, lat = first[0], first[1]
    return (lat, lon)
