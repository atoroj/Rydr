from datetime import datetime
from typing import Optional, List

from app.rides.domain.ride import Ride
from app.routes.domain.route import Route
from app.routes.domain.route_repository import RouteRepository
from app.shared.geo import split_into_segments, total_distance_km_by_segments


class RouteService:
    def __init__(self, repository: RouteRepository):
        self.repository = repository

    def create_route_from_ride(self, ride: Ride, name: str, description: Optional[str], cover_image_url: Optional[str] = None) -> Route:
        if not ride.finished_at:
            raise ValueError("El ride debe estar finalizado para crear una ruta")
        if not ride.track_points:
            raise ValueError("El ride no tiene track points registrados")

        # Trocea por tramos (un corte cada vez que un punto marca
        # `is_segment_start` — el primero tras un "Reanudar") para que ni
        # el geojson ni las cifras conecten el hueco de una pausa: ni como
        # línea recta (carretera falsa) ni como distancia/tiempo
        # recorridos de verdad.
        points_with_flags = [
            (tp.latitude, tp.longitude, tp.is_segment_start) for tp in ride.track_points
        ]
        segments = split_into_segments(points_with_flags)
        if len(segments) <= 1:
            geojson = {
                "type": "LineString",
                "coordinates": [[lon, lat] for lat, lon in segments[0]] if segments else [],
            }
        else:
            geojson = {
                "type": "MultiLineString",
                "coordinates": [[[lon, lat] for lat, lon in segment] for segment in segments],
            }

        distance_km = round(total_distance_km_by_segments(points_with_flags), 2)

        # Duración: suma (último − primer timestamp) DENTRO de cada tramo,
        # así el rato parado entre tramos queda excluido por construcción
        # — no hace falta guardar marcas de pausa/reanudación aparte.
        segment_boundaries: list[tuple[int, int]] = []
        start_index = 0
        for index, tp in enumerate(ride.track_points):
            if index > 0 and tp.is_segment_start:
                segment_boundaries.append((start_index, index - 1))
                start_index = index
        if ride.track_points:
            segment_boundaries.append((start_index, len(ride.track_points) - 1))

        total_seconds = sum(
            (ride.track_points[end].timestamp - ride.track_points[start].timestamp).total_seconds()
            for start, end in segment_boundaries
            if end > start
        )
        if total_seconds > 0:
            duration_minutes = max(1, int(total_seconds / 60))
        else:
            duration_minutes = max(1, int((ride.finished_at - ride.started_at).total_seconds() / 60))

        route = Route(
            id=None,
            name=name,
            description=description,
            author_id=ride.rider_id,
            geojson=geojson,
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            created_at=datetime.now(),
            times_ridden=0,
            cover_image_url=cover_image_url,
        )
        return self.repository.save(route)

    def create_route(
        self,
        name: str,
        description: Optional[str],
        author_id: int,
        geojson: dict,
        distance_km: float,
        duration_minutes: int,
        cover_image_url: Optional[str] = None,
    ) -> Route:
        route = Route(
            id=None,
            name=name,
            description=description,
            author_id=author_id,
            geojson=geojson,
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            created_at=datetime.now(),
            times_ridden=0,
            cover_image_url=cover_image_url,
        )
        return self.repository.save(route)

    def list_public_routes(self) -> List[Route]:
        return self.repository.get_all_public()

    def list_routes_by_author(self, author_id: int) -> List[Route]:
        return self.repository.get_all_by_author(author_id)

    def get_route_by_id(self, route_id: int) -> Optional[Route]:
        return self.repository.get_by_id(route_id)

    def start_riding_route(self, route_id: int) -> None:
        self.repository.increment_times_ridden(route_id)
