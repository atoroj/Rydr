from typing import List
from app.users.domain.user_repository import UserRepository
from app.users.domain.user import User
from app.shared.security import get_password_hashed

class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    def create_user(self, username: str, email:str, password: str):
        if self.repository.get_by_email(email):
            raise ValueError("El email ya existe")
        
        hashed_password = get_password_hashed(password)
        
        user = User(id=None, username=username, email=email, password=hashed_password)
        return self.repository.save(user)
    
    def get_user_by_email(self, email: str):
        return self.repository.get_by_email(email)
    
    def get_all_users(self) -> List[User]:
        return self.repository.get_all()