from typing import List, Optional

from sqlalchemy.orm import Session

from app.riders.domain.follow import Follow, FollowStatus
from app.riders.domain.follow_repository import FollowRepository
from app.riders.infrastructure.follow_model import FollowModel


class SqlAlchemyFollowRepository(FollowRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_domain(self, m: FollowModel) -> Follow:
        return Follow(
            id=m.id, follower_id=m.follower_id, followee_id=m.followee_id,
            status=FollowStatus(m.status), created_at=m.created_at,
        )

    def create(self, follow: Follow) -> Follow:
        m = FollowModel(
            follower_id=follow.follower_id, followee_id=follow.followee_id,
            status=follow.status.value, created_at=follow.created_at,
        )
        self.db.add(m)
        self.db.commit()
        self.db.refresh(m)
        return self._to_domain(m)

    def get_between(self, follower_id: int, followee_id: int) -> Optional[Follow]:
        m = self.db.query(FollowModel).filter(
            FollowModel.follower_id == follower_id, FollowModel.followee_id == followee_id
        ).first()
        return self._to_domain(m) if m else None

    def get_by_id(self, follow_id: int) -> Optional[Follow]:
        m = self.db.query(FollowModel).filter(FollowModel.id == follow_id).first()
        return self._to_domain(m) if m else None

    def list_following(self, user_id: int, status: FollowStatus) -> List[Follow]:
        rows = self.db.query(FollowModel).filter(
            FollowModel.follower_id == user_id, FollowModel.status == status.value
        ).all()
        return [self._to_domain(r) for r in rows]

    def list_followers(self, user_id: int, status: FollowStatus) -> List[Follow]:
        rows = self.db.query(FollowModel).filter(
            FollowModel.followee_id == user_id, FollowModel.status == status.value
        ).all()
        return [self._to_domain(r) for r in rows]

    def list_pending_incoming(self, user_id: int) -> List[Follow]:
        rows = self.db.query(FollowModel).filter(
            FollowModel.followee_id == user_id, FollowModel.status == FollowStatus.PENDING.value
        ).all()
        return [self._to_domain(r) for r in rows]

    def update_status(self, follow_id: int, status: FollowStatus) -> Follow:
        m = self.db.query(FollowModel).filter(FollowModel.id == follow_id).first()
        if m is None:
            raise ValueError("Solicitud no encontrada")
        m.status = status.value
        self.db.commit()
        self.db.refresh(m)
        return self._to_domain(m)

    def delete(self, follow_id: int) -> None:
        m = self.db.query(FollowModel).filter(FollowModel.id == follow_id).first()
        if m:
            self.db.delete(m)
            self.db.commit()

    def delete_all_for_user(self, user_id: int) -> None:
        self.db.query(FollowModel).filter(
            (FollowModel.follower_id == user_id) | (FollowModel.followee_id == user_id)
        ).delete(synchronize_session=False)
        self.db.commit()
