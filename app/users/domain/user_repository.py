from abc import ABC, abstractmethod
from typing import Optional, List
from app.users.domain.user import User

class UserRepository(ABC):
    @abstractmethod
    def save(self, user: User) -> User:
        pass
    
    @abstractmethod
    def get_by_email(self, email: str) -> Optional[User]:
        pass
    
    @abstractmethod
    def get_all(self) -> List[User]:
        pass

    @abstractmethod
    def get_by_id(self, user_id: int) -> Optional[User]:
        pass

    @abstractmethod
    def search_by_username(self, query: str) -> List[User]:
        pass

    @abstractmethod
    def update_profile(self, user_id: int, username: str | None, avatar_url: str | None, is_private: bool | None) -> User:
        pass