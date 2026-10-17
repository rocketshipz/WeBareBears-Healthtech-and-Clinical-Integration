import logging
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy.orm import Session

from app.repositories.base import BaseRepository
from app.models.user_information import UserInformation

logger = logging.getLogger(__name__)


class PatientRepository(BaseRepository[UserInformation, str]):
    """Repository for user_information (demographics and medical background)."""

    def __init__(self, session: Optional[Session] = None):
        self.session = session

    def get_by_id(self, entity_id: str) -> Optional[UserInformation]:
        """Retrieve a user's information by user id."""
        if self.session is None:
            logger.warning("[PatientRepository] No DB session; returning None.")
            return None
        return self.session.query(UserInformation).filter(UserInformation.user_id == entity_id).first()

    def upsert(self, user_id: str, **fields) -> UserInformation:
        """Create or update a user's information and commit."""
        record = self.get_by_id(user_id)
        if record is None:
            record = UserInformation(user_id=user_id, **fields)
            self.session.add(record)
        else:
            for key, value in fields.items():
                setattr(record, key, value)
        record.medical_info_updated_at = datetime.now(timezone.utc)
        self.session.commit()
        self.session.refresh(record)
        return record

    def list_all(self, limit: int = 100, offset: int = 0) -> List[UserInformation]:
        if self.session is None:
            return []
        return self.session.query(UserInformation).offset(offset).limit(limit).all()
