from sqlalchemy import Column, Integer, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.shared.database import Base


class TrackPointModel(Base):
    __tablename__ = "track_points"

    id = Column(Integer, primary_key=True, index=True)
    ride_id = Column(Integer, ForeignKey("rides.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    altitude = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    timestamp = Column(DateTime, nullable=False)
    # True para el primer punto grabado tras un "Reanudar" — marca dónde
    # empieza un tramo nuevo del trazado, para no conectar con una línea
    # recta (ni sumar como distancia real) el hueco de una pausa. Ver
    # `RouteService.create_route_from_ride`.
    is_segment_start = Column(Boolean, default=False)


class RideModel(Base):
    __tablename__ = "rides"

    id = Column(Integer, primary_key=True, index=True)
    rider_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    motorbike_id = Column(Integer, ForeignKey("motorbike.id"), nullable=False)
    started_at = Column(DateTime, nullable=False)
    finished_at = Column(DateTime, nullable=True)
    is_public = Column(Boolean, default=False)

    track_points = relationship("TrackPointModel", backref="ride", lazy="select")
