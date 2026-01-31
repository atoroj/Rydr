from abc import ABC, abstractmethod
from app.auth.domain.auth import Auth


class UserProviderPort(ABC):
    @abstractmethod
    def get_user_by_email(self, email: str) -> Auth | None:
        pass