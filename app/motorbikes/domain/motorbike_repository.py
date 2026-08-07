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