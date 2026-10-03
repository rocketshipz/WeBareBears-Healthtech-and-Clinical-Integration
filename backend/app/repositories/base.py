from abc import ABC, abstractmethod
from typing import Generic, TypeVar, Optional, List

T = TypeVar("T")
ID = TypeVar("ID")


class BaseRepository(ABC, Generic[T, ID]):
    """Abstract base repository interface for data access."""

    @abstractmethod
    def get_by_id(self, entity_id: ID) -> Optional[T]:
        """Fetch a single entity by its ID."""
        pass

    @abstractmethod
    def list_all(self, limit: int = 100, offset: int = 0) -> List[T]:
        """List entities with pagination."""
        pass
