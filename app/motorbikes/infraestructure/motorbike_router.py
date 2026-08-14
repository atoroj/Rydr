from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.motorbikes.application.motorbike_dto import MotorbikeCreate, MotorbikeResponse, MotorbikeUpdate
from app.motorbikes.application.motorbike_service import MotorbikeService
from app.motorbikes.infraestructure.sql_motorbike_repository import SqlAlchemyMotorbikeRepository
from app.shared.auth_dependency import get_current_user
from app.shared.database import get_db
from app.users.infrastructure.user_model import UserModel

router = APIRouter(prefix="/motorbikes", tags=["motorbikes"])

def get_service(db: Session = Depends(get_db)) -> MotorbikeService:
    repository = SqlAlchemyMotorbikeRepository(db)
    return MotorbikeService(repository)

@router.post("", response_model=MotorbikeResponse, status_code=status.HTTP_201_CREATED)
def create_motorbike(request: MotorbikeCreate, service: MotorbikeService = Depends(get_service)):
    return service.create_motorbike(
        user_id=request.user_id,
        type=request.type,
        brand=request.brand,
        model=request.model,
        cc=request.cc,
        alias=request.alias,
        photo_url=request.photo_url,
        year=request.year,
    )

@router.post("/{motorbike_id}/set-current", response_model=MotorbikeResponse)
def set_current_motorbike(
    motorbike_id: int,
    service: MotorbikeService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        return service.set_current(user_id=current_user.id, motorbike_id=motorbike_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

@router.patch("/{motorbike_id}", response_model=MotorbikeResponse)
def update_motorbike(
    motorbike_id: int,
    request: MotorbikeUpdate,
    service: MotorbikeService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        return service.update_motorbike(
            motorbike_id=motorbike_id, user_id=current_user.id,
            type=request.type, brand=request.brand, model=request.model,
            cc=request.cc, alias=request.alias, photo_url=request.photo_url, year=request.year,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

@router.delete("/{motorbike_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_motorbike(
    motorbike_id: int,
    service: MotorbikeService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.delete_motorbike(motorbike_id=motorbike_id, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

@router.get("", response_model=List[MotorbikeResponse])
def get_motorbikes(service: MotorbikeService = Depends(get_service)):
    return service.get_motorbikes()

@router.get("/user/{user_id}", response_model=List[MotorbikeResponse])
def get_motorbikes_by_user(user_id: int, service: MotorbikeService = Depends(get_service)):
    return service.get_motorbikes_by_user_id(user_id)

@router.get("/{motorbike_id}", response_model=MotorbikeResponse)
def get_motorbike(motorbike_id: int, service: MotorbikeService = Depends(get_service)):
    motorbike = service.get_motorbike_by_id(motorbike_id)
    if motorbike is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Motorbike not found")
    return motorbike
