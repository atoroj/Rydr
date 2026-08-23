from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, UniqueConstraint

from app.shared.database import Base


class FollowModel(Base):
    __tablename__ = "follows"

    id = Column(Integer, primary_key=True, index=True)
    follower_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    followee_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String, nullable=False, default="accepted")  # "pending" | "accepted"
    created_at = Column(DateTime, nullable=False)

    __table_args__ = (
        UniqueConstraint("follower_id", "followee_id", name="uq_follow_pair"),
    )
