from abc import ABC, abstractmethod
from typing import Optional, List

from app.routes.domain.route import Route


class RouteRepository(ABC):
    @abstractmethod
    def save(self, route: Route) -> Route:
        pass

    @abstractmethod
    def get_by_id(self, route_id: int) -> Optional[Route]:
        pass

    @abstractmethod
    def get_all_public(self) -> List[Route]:
        pass

    @abstractmethod
    def get_all_by_author(self, author_id: int) -> List[Route]:
        pass

    @abstractmethod
    def increment_times_ridden(self, route_id: int) -> None:
        pass

    @abstractmethod
    def delete(self, route_id: int, author_id: int) -> None:
        """Solo el autor puede borrar."""
        pass
