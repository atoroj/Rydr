from datetime import datetime
from typing import Optional, List

from sqlalchemy.orm import Session

from app.rides.domain.ride import Ride, TrackPoint
from app.rides.domain.ride_repository import RideRepository
from app.rides.infrastructure.ride_model import RideModel, TrackPointModel


class SqlAlchemyRideRepository(RideRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_track_point(self, model: TrackPointModel) -> TrackPoint:
        return TrackPoint(
            id=model.id,
            ride_id=model.ride_id,
            latitude=model.latitude,
            longitude=model.longitude,
            altitude=model.altitude,
            speed=model.speed,
            timestamp=model.timestamp,
            is_segment_start=model.is_segment_start or False,
        )

    def _to_ride(self, model: RideModel) -> Ride:
        return Ride(
            id=model.id,
            rider_id=model.rider_id,
            motorbike_id=model.motorbike_id,
            started_at=model.started_at,
            finished_at=model.finished_at,
            is_public=model.is_public,
            track_points=[self._to_track_point(tp) for tp in model.track_points],
        )

    def save(self, ride: Ride) -> Ride:
        ride_db = RideModel(
            rider_id=ride.rider_id,
            motorbike_id=ride.motorbike_id,
            started_at=ride.started_at,
            finished_at=ride.finished_at,
            is_public=ride.is_public,
        )
        self.db.add(ride_db)
        self.db.commit()
        self.db.refresh(ride_db)
        return self._to_ride(ride_db)

    def get_by_id(self, ride_id: int) -> Optional[Ride]:
        ride_db = self.db.query(RideModel).filter(RideModel.id == ride_id).first()
        if ride_db is None:
            return None
        return self._to_ride(ride_db)

    def get_by_rider_id(self, rider_id: int) -> List[Ride]:
        rides_db = self.db.query(RideModel).filter(RideModel.rider_id == rider_id).all()
        return [self._to_ride(r) for r in rides_db]

    def finish_ride(self, ride_id: int, finished_at: datetime) -> Optional[Ride]:
        ride_db = self.db.query(RideModel).filter(RideModel.id == ride_id).first()
        if ride_db is None:
            return None
        ride_db.finished_at = finished_at
        self.db.commit()
        self.db.refresh(ride_db)
        return self._to_ride(ride_db)

    def add_track_point(self, track_point: TrackPoint) -> TrackPoint:
        tp_db = TrackPointModel(
            ride_id=track_point.ride_id,
            latitude=track_point.latitude,
            longitude=track_point.longitude,
            altitude=track_point.altitude,
            speed=track_point.speed,
            timestamp=track_point.timestamp,
            is_segment_start=track_point.is_segment_start,
        )
        self.db.add(tp_db)
        self.db.commit()
        self.db.refresh(tp_db)
        return self._to_track_point(tp_db)

    def delete(self, ride_id: int) -> bool:
        ride_db = self.db.query(RideModel).filter(RideModel.id == ride_id).first()
        if ride_db is None:
            return False
        # Sin cascade configurado en la relación: borramos los track_points
        # explícitamente primero para no dejar filas huérfanas.
        self.db.query(TrackPointModel).filter(TrackPointModel.ride_id == ride_id).delete()
        self.db.delete(ride_db)
        self.db.commit()
        return True
