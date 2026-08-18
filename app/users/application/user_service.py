import re
from typing import List
from app.users.domain.user_repository import UserRepository
from app.users.domain.user import User
from app.shared.security import get_password_hashed

class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository

    def create_user(self, username: str, email:str, password: str, role: str):
        if self.repository.get_by_email(email):
            raise ValueError("El email ya existe")

        hashed_password = get_password_hashed(password)

        user = User(id=None, username=username, email=email, password=hashed_password, role=role)
        return self.repository.save(user)

    def get_or_create_google_user(self, email: str, google_id: str, avatar_url: str | None) -> User:
        """Login/registro con "Continuar con Google": si ya hay una
        cuenta con ese email (con contraseña, o de un login de Google
        anterior), la enlaza/reutiliza — Google ya ha verificado ese
        email, así que no hace falta contraseña para confiar en él. Si
        no existe, crea una cuenta nueva sin contraseña (solo entrará
        por Google)."""
        existing = self.repository.get_by_email(email)
        if existing:
            if existing.google_id is None:
                return self.repository.set_google_id(existing.id, google_id)
            return existing

        username = self._unique_username_from_email(email)
        user = User(
            id=None, username=username, email=email, password=None,
            role="rider", avatar_url=avatar_url, google_id=google_id,
        )
        return self.repository.save(user)

    def _unique_username_from_email(self, email: str) -> str:
        base = re.sub(r"[^a-z0-9_]", "", email.split("@")[0].lower()) or "rider"
        existing_usernames = {u.username for u in self.repository.search_by_username(base)}
        if base not in existing_usernames:
            return base
        suffix = 2
        while f"{base}{suffix}" in existing_usernames:
            suffix += 1
        return f"{base}{suffix}"

    def get_user_by_email(self, email: str):
        return self.repository.get_by_email(email)
    
    def get_all_users(self) -> List[User]:
        return self.repository.get_all()

    def update_profile(self, user_id: int, username: str | None = None, avatar_url: str | None = None, is_private: bool | None = None) -> User:
        return self.repository.update_profile(user_id, username, avatar_url, is_private)