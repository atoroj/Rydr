from abc import ABC, abstractmethod
from typing import Optional

from app.auth.domain.password_reset import PasswordResetCode


class PasswordResetRepository(ABC):
    @abstractmethod
    def save(self, code: PasswordResetCode) -> PasswordResetCode:
        pass

    @abstractmethod
    def get_active_for_user(self, user_id: int) -> Optional[PasswordResetCode]:
        """El código sin usar y sin caducar más reciente de ese usuario,
        si hay alguno — `invalidate_all_for_user` garantiza que como
        mucho hay uno activo a la vez."""
        pass

    @abstractmethod
    def invalidate_all_for_user(self, user_id: int) -> None:
        """Se llama al pedir un código nuevo — así uno viejo que no se
        llegó a usar no se queda también válido por ahí."""
        pass

    @abstractmethod
    def mark_used(self, code_id: int) -> None:
        pass
