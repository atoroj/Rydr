from abc import ABC, abstractmethod
from typing import Optional, List
from app.motorbikes.domain.motorbike import Motorbike

class MotorbikeRepostiroy(ABC):
    @abstractmethod
    def save(self, motorbike: Motorbike) -> Motorbike:
        pass

    @abstractmethod
    def get_all_by_user_id(self, userId: int) -> List[Motorbike]:
        pass

    @abstractmethod
    def get_by_id(self, id: int) -> Optional[Motorbike]:
        pass

    @abstractmethod
    def get_all(self) -> List[Motorbike]:
        pass

    @abstractmethod
    def set_current(self, user_id: int, motorbike_id: int) -> Motorbike:
        """Marca `motorbike_id` como la moto actual de `user_id` y desmarca
        cualquier otra que lo fuera antes (solo puede haber una a la vez)."""
        pass

    @abstractmethod
    def update(self, motorbike_id: int, user_id: int, **fields) -> Motorbike:
        """Actualiza los campos no-`None` de `fields`. Solo el dueño puede editar."""
        pass

    @abstractmethod
    def delete(self, motorbike_id: int, user_id: int) -> None:
        """Solo el dueño puede borrar."""
        pass