from sqlalchemy.orm import Session
from typing import List
from app.users.domain.user import User
from app.users.domain.user_repository import UserRepository
from app.users.infrastructure.user_model import UserModel

class SqlAlchemyUserRepository(UserRepository):
    def __init__(self, db: Session):
        self.db = db

    def _to_domain(self, user_db: UserModel) -> User:
        return User(
            id=user_db.id, email=user_db.email, username=user_db.username,
            password=user_db.password, role=user_db.role,
            avatar_url=user_db.avatar_url, is_private=bool(user_db.is_private),
            google_id=user_db.google_id,
        )

    def save(self, user: User):
        # `role`/`avatar_url`/`google_id` se quedaban fuera antes (el
        # registro por Google necesita los tres: rol para el JWT nada
        # más crear la cuenta, avatar de perfil de Google, y el id para
        # poder enlazarla luego).
        user_db = UserModel(
            email=user.email, username=user.username, password=user.password,
            role=user.role, avatar_url=user.avatar_url, google_id=user.google_id,
        )
        self.db.add(user_db)
        self.db.commit()
        self.db.refresh(user_db)

        return self._to_domain(user_db)

    def get_by_email(self, email: str) -> User | None:
        user_db = self.db.query(UserModel).filter(UserModel.email == email).first()
        if not user_db:
            return None
        return self._to_domain(user_db)

    def get_all(self) -> List[User]:
        users_db = self.db.query(UserModel).all()

        return [self._to_domain(u) for u in users_db]

    def get_by_id(self, user_id: int) -> User | None:
        user_db = self.db.query(UserModel).filter(UserModel.id == user_id).first()
        if not user_db:
            return None
        return self._to_domain(user_db)

    def search_by_username(self, query: str) -> List[User]:
        users_db = self.db.query(UserModel).filter(
            UserModel.username.ilike(f"%{query}%")
        ).limit(20).all()
        return [self._to_domain(u) for u in users_db]

    def update_profile(self, user_id: int, username: str | None, avatar_url: str | None, is_private: bool | None) -> User:
        user_db = self.db.query(UserModel).filter(UserModel.id == user_id).first()
        if user_db is None:
            raise ValueError("Usuario no encontrado")

        if username is not None:
            user_db.username = username
        if avatar_url is not None:
            user_db.avatar_url = avatar_url
        if is_private is not None:
            user_db.is_private = is_private

        self.db.commit()
        self.db.refresh(user_db)
        return self._to_domain(user_db)

    def set_google_id(self, user_id: int, google_id: str) -> User:
        user_db = self.db.query(UserModel).filter(UserModel.id == user_id).first()
        if user_db is None:
            raise ValueError("Usuario no encontrado")
        user_db.google_id = google_id
        self.db.commit()
        self.db.refresh(user_db)
        return self._to_domain(user_db)
