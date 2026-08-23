from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class FollowStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"


@dataclass
class Follow:
    id: int | None
    follower_id: int
    followee_id: int
    status: FollowStatus
    created_at: datetime
