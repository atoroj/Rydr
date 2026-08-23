from sqlalchemy import Boolean, Column, ForeignKey, Integer, String

from app.shared.database import Base


class MotorbikeModel(Base):
    __tablename__ = 'motorbike'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    type = Column(String)
    brand = Column(String)
    model = Column(String)
    cc = Column(Integer)
    alias = Column(String)
    photo_url = Column(String, nullable=True)
    is_current = Column(Boolean, default=False, nullable=False)
    year = Column(Integer, nullable=True)
