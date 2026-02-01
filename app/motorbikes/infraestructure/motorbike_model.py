from sqlalchemy import Column, ForeignKey, Integer, String

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
