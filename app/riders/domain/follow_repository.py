from abc import ABC, abstractmethod
from typing import List, Optional

from app.riders.domain.follow import Follow, FollowStatus


class FollowRepository(ABC):
    @abstractmethod
    def create(self, follow: Follow) -> Follow:
        pass

    @abstractmethod
    def get_between(self, follower_id: int, followee_id: int) -> Optional[Follow]:
        pass

    @abstractmethod
    def get_by_id(self, follow_id: int) -> Optional[Follow]:
        pass

    @abstractmethod
    def list_following(self, user_id: int, status: FollowStatus) -> List[Follow]:
        pass

    @abstractmethod
    def list_followers(self, user_id: int, status: FollowStatus) -> List[Follow]:
        pass

    @abstractmethod
    def list_pending_incoming(self, user_id: int) -> List[Follow]:
        pass

    @abstractmethod
    def update_status(self, follow_id: int, status: FollowStatus) -> Follow:
        pass

    @abstractmethod
    def delete(self, follow_id: int) -> None:
        pass
