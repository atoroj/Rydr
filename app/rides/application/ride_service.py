from datetime import datetime
from typing import Optional, List

from app.rides.domain.ride import Ride, TrackPoint
from app.rides.domain.ride_repository import RideRepository


class RideService:
    def __init__(self, repository: RideRepository):
        self.repository = repository

    def start_ride(self, rider_id: int, motorbike_id: int) -> Ride:
        ride = Ride(
            id=None,
            rider_id=rider_id,
            motorbike_id=motorbike_id,
            started_at=datetime.now(),
            finished_at=None,
            is_public=False,
        )
        return self.repository.save(ride)

    def add_track_point(
        self,
        ride_id: int,
        latitude: float,
        longitude: float,
        altitude: Optional[float],
        speed: Optional[float],
        timestamp: datetime,
    ) -> TrackPoint:
        track_point = TrackPoint(
            id=None,
            ride_id=ride_id,
            latitude=latitude,
            longitude=longitude,
            altitude=altitude,
            speed=speed,
            timestamp=timestamp,
        )
        return self.repository.add_track_point(track_point)

    def finish_ride(self, ride_id: int) -> Optional[Ride]:
        return self.repository.finish_ride(ride_id, datetime.now())

    def get_rides_by_rider(self, rider_id: int) -> List[Ride]:
        return self.repository.get_by_rider_id(rider_id)

    def get_ride_by_id(self, ride_id: int) -> Optional[Ride]:
        return self.repository.get_by_id(ride_id)

    def delete_ride(self, ride_id: int) -> bool:
        return self.repository.delete(ride_id)
