from sqlalchemy import Boolean, Column, Integer, String
from app.shared.database import Base

class UserModel(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    username = Column(String)
    password = Column(String)
    role = Column(String, default="user")
    avatar_url = Column(String, nullable=True)
    is_private = Column(Boolean, default=False, nullable=False)
