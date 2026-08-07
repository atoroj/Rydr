from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.rides.application.ride_dto import (
    AddTrackPointRequest,
    RideResponse,
    StartRideRequest,
    TrackPointResponse,
)
from app.rides.application.ride_service import RideService
from app.rides.infrastructure.sql_ride_repository import SqlAlchemyRideRepository
from app.shared.database import get_db

router = APIRouter(prefix="/rides", tags=["rides"])


def get_service(db: Session = Depends(get_db)) -> RideService:
    return RideService(SqlAlchemyRideRepository(db))


@router.post("/", response_model=RideResponse, status_code=status.HTTP_201_CREATED)
def start_ride(request: StartRideRequest, service: RideService = Depends(get_service)):
    return service.start_ride(request.rider_id, request.motorbike_id)


@router.patch("/{ride_id}/finish", response_model=RideResponse)
def finish_ride(ride_id: int, service: RideService = Depends(get_service)):
    ride = service.finish_ride(ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
    return ride


@router.post("/{ride_id}/track-points", response_model=TrackPointResponse, status_code=status.HTTP_201_CREATED)
def add_track_point(
    ride_id: int,
    request: AddTrackPointRequest,
    service: RideService = Depends(get_service),
):
    return service.add_track_point(
        ride_id=ride_id,
        latitude=request.latitude,
        longitude=request.longitude,
        altitude=request.altitude,
        speed=request.speed,
        timestamp=request.timestamp,
    )


@router.get("/rider/{rider_id}", response_model=List[RideResponse])
def get_rides_by_rider(rider_id: int, service: RideService = Depends(get_service)):
    return service.get_rides_by_rider(rider_id)


@router.get("/{ride_id}", response_model=RideResponse)
def get_ride(ride_id: int, service: RideService = Depends(get_service)):
    ride = service.get_ride_by_id(ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
    return ride
