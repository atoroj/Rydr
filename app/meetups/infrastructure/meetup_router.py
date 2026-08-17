from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.meetups.application.meetup_dto import (
    CreateMeetupRequest,
    LiveLocationResponse,
    MeetupOrganizerResponse,
    MeetupResponse,
    ParticipantResponse,
    UpdateLocationRequest,
    UpdateMeetupRequest,
)
from app.meetups.application.meetup_service import MeetupService, MeetupView
from app.meetups.infrastructure.sql_meetup_repository import SqlAlchemyMeetupRepository
from app.riders.infrastructure.sql_follow_repository import SqlAlchemyFollowRepository
from app.shared.auth_dependency import get_current_user
from app.shared.database import get_db
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.infrastructure.user_model import UserModel

router = APIRouter(prefix="/meetups", tags=["meetups"])


def get_service(db: Session = Depends(get_db)) -> MeetupService:
    return MeetupService(
        meetup_repo=SqlAlchemyMeetupRepository(db),
        user_repo=SqlAlchemyUserRepository(db),
        follow_repo=SqlAlchemyFollowRepository(db),
    )


def _to_response(view: MeetupView) -> MeetupResponse:
    return MeetupResponse(
        id=view.meetup.id,
        organizer=MeetupOrganizerResponse(
            id=view.organizer.id, username=view.organizer.username, avatar_url=view.organizer.avatar_url,
        ),
        title=view.meetup.title, description=view.meetup.description,
        location_name=view.meetup.location_name, location_lat=view.meetup.location_lat,
        location_lng=view.meetup.location_lng, scheduled_at=view.meetup.scheduled_at,
        max_participants=view.meetup.max_participants, participant_count=view.participant_count,
        is_private=view.meetup.is_private, is_joined=view.is_joined, is_organizer=view.is_organizer,
        created_at=view.meetup.created_at,
    )


@router.post("", response_model=MeetupResponse, status_code=status.HTTP_201_CREATED)
def create_meetup(
    request: CreateMeetupRequest,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    meetup = service.create(
        organizer_id=current_user.id, title=request.title, description=request.description,
        location_name=request.location_name, location_lat=request.location_lat,
        location_lng=request.location_lng, scheduled_at=request.scheduled_at,
        max_participants=request.max_participants, is_private=request.is_private,
    )
    return _to_response(service.get_view(meetup.id, current_user.id))


# ── OJO: "/discover" y "/mine" tienen que registrarse ANTES de "/{meetup_id}"
# — FastAPI compara las rutas en orden de registro y "/{meetup_id}" (un solo
# segmento, sin restricción de tipo a nivel de path) capturaría "discover"/
# "mine" como si fueran el id, dando un 422 en vez de resolver bien. ──────

@router.get("/discover", response_model=List[MeetupResponse])
def discover_meetups(
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return [_to_response(v) for v in service.list_discover(current_user.id)]


@router.get("/mine", response_model=List[MeetupResponse])
def my_meetups(
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return [_to_response(v) for v in service.list_mine(current_user.id)]


@router.get("/{meetup_id}", response_model=MeetupResponse)
def get_meetup(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        return _to_response(service.get_view(meetup_id, current_user.id))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.patch("/{meetup_id}", response_model=MeetupResponse)
def update_meetup(
    meetup_id: int,
    request: UpdateMeetupRequest,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.update(meetup_id, current_user.id, **request.model_dump(exclude_unset=True))
        return _to_response(service.get_view(meetup_id, current_user.id))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.delete("/{meetup_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_meetup(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.delete(meetup_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post("/{meetup_id}/join", status_code=status.HTTP_204_NO_CONTENT)
def join_meetup(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.join(meetup_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.post("/{meetup_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
def leave_meetup(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.leave(meetup_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{meetup_id}/participants", response_model=List[ParticipantResponse])
def list_participants(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return [
        ParticipantResponse(id=u.id, username=u.username, avatar_url=u.avatar_url)
        for u in service.get_participants(meetup_id)
    ]


@router.post("/{meetup_id}/location", status_code=status.HTTP_204_NO_CONTENT)
def update_location(
    meetup_id: int,
    request: UpdateLocationRequest,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.update_location(meetup_id, current_user.id, request.lat, request.lng)
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.get("/{meetup_id}/live-locations", response_model=List[LiveLocationResponse])
def list_live_locations(
    meetup_id: int,
    service: MeetupService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        views = service.list_live_locations(meetup_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    return [
        LiveLocationResponse(
            user_id=v.user.id, username=v.user.username, avatar_url=v.user.avatar_url,
            lat=v.location.lat, lng=v.location.lng, updated_at=v.location.updated_at,
        )
        for v in views
    ]
