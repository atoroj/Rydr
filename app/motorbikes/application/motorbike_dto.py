from pydantic import BaseModel, ConfigDict
from typing import Optional
from app.motorbikes.domain.motorbike import MotorBykeType

class MotorbikeCreate(BaseModel):
    user_id: int
    type: MotorBykeType
    brand: str
    model: str
    cc: int
    alias: Optional[str] = None
    photo_url: Optional[str] = None
    year: Optional[int] = None

class MotorbikeUpdate(BaseModel):
    type: Optional[MotorBykeType] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    cc: Optional[int] = None
    alias: Optional[str] = None
    photo_url: Optional[str] = None
    year: Optional[int] = None

class MotorbikeResponse(BaseModel):
    id: int
    user_id: int
    type: MotorBykeType
    brand: str
    model: str
    cc: int
    alias: Optional[str] = None
    photo_url: Optional[str] = None
    is_current: bool = False
    year: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)