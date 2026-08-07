from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.rides.application.ride_service import RideService
from app.rides.infrastructure.sql_ride_repository import SqlAlchemyRideRepository
from app.routes.application.route_dto import (
    CreateRouteFromRideRequest,
    CreateRouteRequest,
    RouteResponse,
)
from app.routes.application.route_service import RouteService
from app.routes.infrastructure.sql_route_repository import SqlAlchemyRouteRepository
from app.shared.database import get_db

router = APIRouter(prefix="/routes", tags=["routes"])


def get_service(db: Session = Depends(get_db)) -> RouteService:
    return RouteService(SqlAlchemyRouteRepository(db))


def get_ride_service(db: Session = Depends(get_db)) -> RideService:
    return RideService(SqlAlchemyRideRepository(db))


@router.get("/", response_model=List[RouteResponse])
def list_routes(service: RouteService = Depends(get_service)):
    return service.list_public_routes()


@router.post("/", response_model=RouteResponse, status_code=status.HTTP_201_CREATED)
def create_route(request: CreateRouteRequest, service: RouteService = Depends(get_service)):
    return service.create_route(
        name=request.name,
        description=request.description,
        author_id=request.author_id,
        geojson=request.geojson,
        distance_km=request.distance_km,
        duration_minutes=request.duration_minutes,
    )


@router.post("/from-ride", response_model=RouteResponse, status_code=status.HTTP_201_CREATED)
def create_route_from_ride(
    request: CreateRouteFromRideRequest,
    route_service: RouteService = Depends(get_service),
    ride_service: RideService = Depends(get_ride_service),
):
    ride = ride_service.get_ride_by_id(request.ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
    try:
        return route_service.create_route_from_ride(ride, request.name, request.description)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{route_id}", response_model=RouteResponse)
def get_route(route_id: int, service: RouteService = Depends(get_service)):
    route = service.get_route_by_id(route_id)
    if route is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found")
    return route


@router.post("/{route_id}/ride", status_code=status.HTTP_204_NO_CONTENT)
def ride_route(route_id: int, service: RouteService = Depends(get_service)):
    route = service.get_route_by_id(route_id)
    if route is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found")
    service.start_riding_route(route_id)
