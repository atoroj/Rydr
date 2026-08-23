from fastapi import APIRouter, Depends, HTTPException, Request, status
from typing import List
from sqlalchemy.orm import Session
from app.shared.rate_limit import limiter
from app.meetups.infrastructure.sql_meetup_repository import SqlAlchemyMeetupRepository
from app.motorbikes.infraestructure.sql_motorbike_repository import SqlAlchemyMotorbikeRepository
from app.riders.infrastructure.sql_follow_repository import SqlAlchemyFollowRepository
from app.rides.infrastructure.sql_ride_repository import SqlAlchemyRideRepository
from app.routes.infrastructure.sql_route_repository import SqlAlchemyRouteRepository
from app.shared.auth_dependency import get_current_user
from app.shared.database import get_db
from app.shared.errors import NotFoundError
from app.users.application.account_deletion_service import AccountDeletionService
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.infrastructure.user_model import UserModel
from app.users.application.user_service import UserService
from app.users.application.user_dto import UpdateProfileRequest, UserCreate, UserResponse

router = APIRouter(prefix="/users", tags=["Usuarios"])

#Inyección de dependencias manualmente
def get_service(db: Session = Depends(get_db)) -> UserService:
    repository = SqlAlchemyUserRepository(db)
    return UserService(repository)

def get_account_deletion_service(db: Session = Depends(get_db)) -> AccountDeletionService:
    return AccountDeletionService(
        user_repo=SqlAlchemyUserRepository(db),
        motorbike_repo=SqlAlchemyMotorbikeRepository(db),
        ride_repo=SqlAlchemyRideRepository(db),
        route_repo=SqlAlchemyRouteRepository(db),
        meetup_repo=SqlAlchemyMeetupRepository(db),
        follow_repo=SqlAlchemyFollowRepository(db),
    )

@router.post("/", response_model=UserResponse)
@limiter.limit("5/minute")
def create_user(request: Request, body: UserCreate, service: UserService = Depends(get_service)):
    try:
        created_user = service.create_user(body.username, body.email, body.password, body.role)
        return created_user
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

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

@router.patch("/me", response_model=UserResponse)
def update_my_profile(
    request: UpdateProfileRequest,
    service: UserService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return service.update_profile(
        user_id=current_user.id,
        username=request.username,
        avatar_url=request.avatar_url,
        is_private=request.is_private,
    )

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    service: AccountDeletionService = Depends(get_account_deletion_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.delete_account(current_user.id)
    except NotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    return None