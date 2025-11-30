from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class AuthUser:
    email: str
    password_hash: str
    role: str

class UserProviderPort(ABC):
    @abstractmethod
    def get_user_by_email(self, email: str) -> AuthUser | None:
        pass