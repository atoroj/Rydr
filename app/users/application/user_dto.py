from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    role: str = "rider"

class UserResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    avatar_url: Optional[str] = None
    is_private: bool = False

    model_config = ConfigDict(from_attributes=True)

class UpdateProfileRequest(BaseModel):
    username: Optional[str] = None
    avatar_url: Optional[str] = None
    is_private: Optional[bool] = None