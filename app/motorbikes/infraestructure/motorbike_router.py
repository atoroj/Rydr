from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import APIRouter
from sqlalchemy.orm import Session

from app.motorbikes.application.motorbike_service import MotorbikeService
from app.shared.database import get_db
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository

router = APIRouter(prefix="/motorbikes", tags=["motorbikes"])

#Inyección de dependencias manualmente
def get_service(db: Session = Depends(get_db)) -> MotorbikeService:
    repository = SqlAlchemyUserRepository(db)
    return MotorbikeService(repository)