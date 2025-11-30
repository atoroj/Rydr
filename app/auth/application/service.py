from app.auth.domain.ports import UserProviderPort
from app.shared.security import verify_password, create_access_token

class AuthService:
    def __init__(self, user_provider: UserProviderPort):
        self.user_provider = user_provider
        
    def login(self, email: str, password: str):
        user = self.user_provider.get_user_by_email(email)
        if not user or not verify_password(password, user.password_hash):
            return None
        
        return create_access_token(data={"sub": user.email, "role": user.role})