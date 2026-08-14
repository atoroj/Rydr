from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON

from app.shared.database import Base


class RouteModel(Base):
    __tablename__ = "routes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    geojson = Column(JSON, nullable=False)
    distance_km = Column(Float, nullable=False)
    duration_minutes = Column(Integer, nullable=False)
    created_at = Column(DateTime, nullable=False)
    times_ridden = Column(Integer, default=0, nullable=False)
    cover_image_url = Column(String, nullable=True)
