from enum import Enum
from dataclasses import dataclass

class MotorBykeType(Enum):
    NAKED = "Naked"
    SPORT = "Sport"
    CUSTOM = "Custom"
    ATV = "ATV"
    TOURING = "Touring"
    MOTOCROSS = "Motocross"
    SCOOTER = "Scooter"

@dataclass
class Motorbike:
    id: int | None
    user_id: int
    type: MotorBykeType
    brand: str
    model: str
    cc: int
    alias: str | None