from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.badges.application.badge_dto import BadgeResponse
from app.badges.application.badge_service import BadgeService
from app.meetups.infrastructure.sql_meetup_repository import SqlAlchemyMeetupRepository
from app.rides.infrastructure.sql_ride_repository import SqlAlchemyRideRepository
from app.shared.auth_dependency import get_current_user
from app.shared.database import get_db
from app.users.infrastructure.user_model import UserModel

# Mismo prefijo "/riders" que ya usa follow_router — es el mismo recurso
# ("un rider"), solo un router aparte para no mezclar seguir/perfil con
# insignias en el mismo archivo. No colisiona: FastAPI compara la ruta
# completa ("/riders/{id}/badges" vs "/riders/{id}/profile"), no el
# prefijo por sí solo.
router = APIRouter(prefix="/riders", tags=["badges"])


def get_service(db: Session = Depends(get_db)) -> BadgeService:
    return BadgeService(
        ride_repo=SqlAlchemyRideRepository(db),
        meetup_repo=SqlAlchemyMeetupRepository(db),
    )


@router.get("/{rider_id}/badges", response_model=List[BadgeResponse])
def get_badges(
    rider_id: int,
    service: BadgeService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return [
        BadgeResponse(id=b.id, title=b.title, description=b.description, icon=b.icon, achieved=b.achieved)
        for b in service.get_badges(rider_id)
    ]
