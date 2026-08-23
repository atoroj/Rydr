from pydantic import BaseModel


class BadgeResponse(BaseModel):
    id: str
    title: str
    description: str
    icon: str
    achieved: bool
