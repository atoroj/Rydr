from app.auth.domain.ports import UserProviderPort, AuthUser
from app.users.application.user_service import UserService

class LocalUserAdapter(UserProviderPort):
    def __init__(self, service: UserService):
        self.service = service
        
    def get_user_by_email(self, email: str) -> AuthUser | None:
        # Llamamos al otro slice
        real_user = self.service.get_user_by_email(email)
        
        if not real_user:
            return None
            
        # Convertimos User (Dominio Users) -> AuthUser (Dominio Auth)
        return AuthUser(
            email=real_user.email,
            password_hash=real_user.password,
            role="user" # O real_user.role si lo tienes
        )