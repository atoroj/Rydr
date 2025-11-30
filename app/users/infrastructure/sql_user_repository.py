from sqlalchemy.orm import Session
from typing import List
from app.users.domain.user import User
from app.users.domain.user_repository import UserRepository
from app.users.infrastructure.models import UserModel

class SqlAlchemyUserRepository(UserRepository):
    def __init__(self, db: Session):
        self.db = db
        
    def save(self, user: User):
        user_db = UserModel(email=user.email, username=user.username, password=user.password)
        self.db.add(user_db)
        self.db.commit()
        self.db.refresh(user_db)
        
        return User(id=user_db.id, email=user_db.email, username=user_db.username, password=user_db.password)
    
    def get_by_email(self, email: str) -> User | None:
        user_db = self.db.query(UserModel).filter(UserModel.email == email).first()
        if not user_db:
            return None
        return User(id=user_db.id, email=user_db.email, username=user_db.username, password=user_db.password)        
    
    def get_all(self) -> List[User]:
        users_db = self.db.query(UserModel).all()
        
        return [
            User(id=u.id, email=u.email, username=u.username, password=u.password)
            for u in users_db
        ]