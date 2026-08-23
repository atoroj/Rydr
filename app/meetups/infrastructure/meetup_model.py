from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint

from app.shared.database import Base


class MeetupModel(Base):
    __tablename__ = "meetups"

    id = Column(Integer, primary_key=True, index=True)
    organizer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    location_name = Column(String, nullable=True)
    location_lat = Column(Float, nullable=False)
    location_lng = Column(Float, nullable=False)
    scheduled_at = Column(DateTime, nullable=False)
    max_participants = Column(Integer, nullable=True)
    is_private = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, nullable=False)
    location_hidden = Column(Boolean, default=False, nullable=False)
    approximate_area = Column(String, nullable=True)
    location_revealed = Column(Boolean, default=False, nullable=False)


class MeetupParticipantModel(Base):
    __tablename__ = "meetup_participants"

    id = Column(Integer, primary_key=True, index=True)
    meetup_id = Column(Integer, ForeignKey("meetups.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    joined_at = Column(DateTime, nullable=False)
    # Ubicación en vivo — solo el último punto compartido, sin historial.
    # Nullable: la mayoría de participantes nunca la usan.
    last_lat = Column(Float, nullable=True)
    last_lng = Column(Float, nullable=True)
    last_location_at = Column(DateTime, nullable=True)

    __table_args__ = (
        UniqueConstraint("meetup_id", "user_id", name="uq_meetup_participant"),
    )
