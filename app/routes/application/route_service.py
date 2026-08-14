from datetime import datetime
from typing import Optional, List

from app.rides.domain.ride import Ride
from app.routes.domain.route import Route
from app.routes.domain.route_repository import RouteRepository
from app.shared.geo import total_distance_km


class RouteService:
    def __init__(self, repository: RouteRepository):
        self.repository = repository

    def create_route_from_ride(self, ride: Ride, name: str, description: Optional[str], cover_image_url: Optional[str] = None) -> Route:
        if not ride.finished_at:
            raise ValueError("El ride debe estar finalizado para crear una ruta")
        if not ride.track_points:
            raise ValueError("El ride no tiene track points registrados")

        coordinates = [[tp.longitude, tp.latitude] for tp in ride.track_points]
        geojson = {"type": "LineString", "coordinates": coordinates}

        points = [(tp.latitude, tp.longitude) for tp in ride.track_points]
        distance_km = round(total_distance_km(points), 2)

        # Calcula duración desde el primer al último track point (más preciso que started_at/finished_at)
        if len(ride.track_points) >= 2:
            delta = ride.track_points[-1].timestamp - ride.track_points[0].timestamp
            duration_minutes = max(1, int(delta.total_seconds() / 60))
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
