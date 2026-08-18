from abc import ABC, abstractmethod
from app.auth.domain.auth import Auth


class UserProviderPort(ABC):
    @abstractmethod
    def get_user_by_email(self, email: str) -> Auth | None:
        pass

    @abstractmethod
    def get_or_create_google_user(self, email: str, google_id: str, avatar_url: str | None) -> Auth:
        """Login/registro con "Continuar con Google" — ver
        `UserService.get_or_create_google_user`."""
        pass