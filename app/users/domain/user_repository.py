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