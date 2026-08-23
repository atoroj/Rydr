from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.auth.domain.password_reset import PasswordResetCode
from app.auth.domain.password_reset_repository import PasswordResetRepository
from app.auth.infrastructure.password_reset_model import PasswordResetCodeModel


class SqlAlchemyPasswordResetRepository(PasswordResetRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_domain(self, code_db: PasswordResetCodeModel) -> PasswordResetCode:
        return PasswordResetCode(
            id=code_db.id, user_id=code_db.user_id, code_hash=code_db.code_hash,
            expires_at=code_db.expires_at, used=bool(code_db.used), created_at=code_db.created_at,
        )

    def save(self, code: PasswordResetCode) -> PasswordResetCode:
        code_db = PasswordResetCodeModel(
            user_id=code.user_id, code_hash=code.code_hash, expires_at=code.expires_at,
            used=code.used, created_at=code.created_at,
        )
        self.db.add(code_db)
        self.db.commit()
        self.db.refresh(code_db)
        return self._to_domain(code_db)

    def get_active_for_user(self, user_id: int) -> Optional[PasswordResetCode]:
        code_db = (
            self.db.query(PasswordResetCodeModel)
            .filter(PasswordResetCodeModel.user_id == user_id, PasswordResetCodeModel.used.is_(False))
            .order_by(PasswordResetCodeModel.created_at.desc())
            .first()
        )
        if not code_db:
            return None
        return self._to_domain(code_db)

    def invalidate_all_for_user(self, user_id: int) -> None:
        self.db.query(PasswordResetCodeModel).filter(
            PasswordResetCodeModel.user_id == user_id, PasswordResetCodeModel.used.is_(False)
        ).update({"used": True})
        self.db.commit()

    def mark_used(self, code_id: int) -> None:
        self.db.query(PasswordResetCodeModel).filter(PasswordResetCodeModel.id == code_id).update({"used": True})
        self.db.commit()
