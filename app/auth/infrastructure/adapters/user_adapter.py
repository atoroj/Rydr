from app.auth.domain.ports import UserProviderPort
from app.auth.domain.auth import Auth
from app.users.application.user_service import UserService

class LocalUserAdapter(UserProviderPort):
    def __init__(self, service: UserService):
        self.service = service
        
    def get_user_by_email(self, email: str) -> Auth | None:
        # Llamamos al otro slice
        real_user = self.service.get_user_by_email(email)
        
        if not real_user:
            return None
            
        # Convertimos User (Dominio Users) -> Auth (Dominio Auth)
        return Auth(
            email=real_user.email,
            password_hash=real_user.password,
            role=real_user.role
        )

    def get_or_create_google_user(self, email: str, google_id: str, avatar_url: str | None) -> Auth:
        real_user = self.service.get_or_create_google_user(email, google_id, avatar_url)
        return Auth(email=real_user.email, password_hash=real_user.password, role=real_user.role)