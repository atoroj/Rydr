from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.motorbikes.application.motorbike_dto import MotorbikeCreate, MotorbikeResponse
from app.motorbikes.application.motorbike_service import MotorbikeService
from app.motorbikes.infraestructure.sql_motorbike_repository import SqlAlchemyMotorbikeRepository
from app.shared.database import get_db

router = APIRouter(prefix="/motorbikes", tags=["motorbikes"])

def get_service(db: Session = Depends(get_db)) -> MotorbikeService:
    repository = SqlAlchemyMotorbikeRepository(db)
    return MotorbikeService(repository)

@router.post("/", response_model=MotorbikeResponse, status_code=status.HTTP_201_CREATED)
def create_motorbike(request: MotorbikeCreate, service: MotorbikeService = Depends(get_service)):
    return service.create_motorbike(
        user_id=request.user_id,
        type=request.type,
        brand=request.brand,
        model=request.model,
        cc=request.cc,
        alias=request.alias,
    )

@router.get("/", response_model=List[MotorbikeResponse])
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
