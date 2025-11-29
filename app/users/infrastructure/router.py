from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from app.shared.database import get_db
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.application.user_service import UserService
from app.users.application.user_dto import UserCreate, UserResponse

router = APIRouter(prefix="/users", tags=["Usuarios"])

#Inyección de dependencias manualmente
def get_service(db: Session = Depends(get_db)) -> UserService:
    repository = SqlAlchemyUserRepository(db)
    return UserService(repository)

@router.post("/", response_model=UserResponse)
def create_user(request: UserCreate, service: UserService = Depends(get_service)):
    try:
        created_user = service.create_user(request.username, request.email, request.password)
        return created_user
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", response_model=List[UserResponse])
def get_users(service: UserService = Depends(get_service)):
    return service.get_all_users()

@router.get("/email/{email}", response_model=UserResponse)
def get_user_by_email(email: str, service: UserService = Depends(get_service)):
    user = service.get_user_by_email(email)
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Usuario no encontrado"
        )
        
    return user