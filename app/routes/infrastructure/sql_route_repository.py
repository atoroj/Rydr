from typing import Optional, List

from sqlalchemy.orm import Session

from app.routes.domain.route import Route
from app.routes.domain.route_repository import RouteRepository
from app.routes.infrastructure.route_model import RouteModel


class SqlAlchemyRouteRepository(RouteRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_route(self, model: RouteModel) -> Route:
        return Route(
            id=model.id,
            name=model.name,
            description=model.description,
            author_id=model.author_id,
            geojson=model.geojson,
            distance_km=model.distance_km,
            duration_minutes=model.duration_minutes,
            created_at=model.created_at,
            times_ridden=model.times_ridden,
        )

    def save(self, route: Route) -> Route:
        route_db = RouteModel(
            name=route.name,
            description=route.description,
            author_id=route.author_id,
            geojson=route.geojson,
            distance_km=route.distance_km,
            duration_minutes=route.duration_minutes,
            created_at=route.created_at,
            times_ridden=route.times_ridden,
        )
        self.db.add(route_db)
        self.db.commit()
        self.db.refresh(route_db)
        return self._to_route(route_db)

    def get_by_id(self, route_id: int) -> Optional[Route]:
        route_db = self.db.query(RouteModel).filter(RouteModel.id == route_id).first()
        if route_db is None:
            return None
        return self._to_route(route_db)

    def get_all_public(self) -> List[Route]:
        routes_db = self.db.query(RouteModel).all()
        return [self._to_route(r) for r in routes_db]

    def increment_times_ridden(self, route_id: int) -> None:
        route_db = self.db.query(RouteModel).filter(RouteModel.id == route_id).first()
        if route_db:
            route_db.times_ridden += 1
            self.db.commit()
