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

class MotorbikeResponse(BaseModel):
    id: int
    user_id: int
    type: MotorBykeType
    brand: str
    model: str
    cc: int
    alias: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)