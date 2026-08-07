from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional, List

from app.rides.domain.ride import Ride, TrackPoint


class RideRepository(ABC):
    @abstractmethod
    def save(self, ride: Ride) -> Ride:
        pass

    @abstractmethod
    def get_by_id(self, ride_id: int) -> Optional[Ride]:
        pass

    @abstractmethod
    def get_by_rider_id(self, rider_id: int) -> List[Ride]:
        pass

    @abstractmethod
    def finish_ride(self, ride_id: int, finished_at: datetime) -> Optional[Ride]:
        pass

    @abstractmethod
    def add_track_point(self, track_point: TrackPoint) -> TrackPoint:
        pass
