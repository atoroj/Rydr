from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.motorbikes.domain.motorbike import Motorbike
from app.motorbikes.infraestructure.sql_motorbike_repository import SqlAlchemyMotorbikeRepository
from app.riders.application.follow_dto import (
    FeedItemResponse,
    FollowRequestResponse,
    MotorbikeSummary,
    RiderProfileResponse,
    RiderSummaryResponse,
    RouteSummaryResponse,
)
from app.riders.application.follow_service import FollowService
from app.riders.infrastructure.sql_follow_repository import SqlAlchemyFollowRepository
from app.routes.infrastructure.sql_route_repository import SqlAlchemyRouteRepository
from app.shared.auth_dependency import get_current_user
from app.shared.database import get_db
from app.shared.errors import NotFoundError
from app.users.domain.user import User
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.infrastructure.user_model import UserModel

router = APIRouter(prefix="/riders", tags=["riders"])


def get_service(db: Session = Depends(get_db)) -> FollowService:
    return FollowService(
        follow_repo=SqlAlchemyFollowRepository(db),
        user_repo=SqlAlchemyUserRepository(db),
        motorbike_repo=SqlAlchemyMotorbikeRepository(db),
        route_repo=SqlAlchemyRouteRepository(db),
    )


def _motorbike_summary(motorbike: Optional[Motorbike]) -> Optional[MotorbikeSummary]:
    if motorbike is None:
        return None
    return MotorbikeSummary(
        id=motorbike.id, brand=motorbike.brand, model=motorbike.model,
        alias=motorbike.alias, photo_url=motorbike.photo_url, year=motorbike.year,
    )


def _rider_summary(service: FollowService, user: User, viewer_id: int) -> RiderSummaryResponse:
    return RiderSummaryResponse(
        id=user.id, username=user.username, avatar_url=user.avatar_url,
        is_private=user.is_private,
        follow_status=service.follow_status_between(viewer_id, user.id),
        current_motorbike=_motorbike_summary(service.get_current_motorbike(user.id)),
    )


@router.get("/search", response_model=List[RiderSummaryResponse])
def search_riders(
    q: str,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    return [_rider_summary(service, u, current_user.id) for u in service.search(q, current_user.id)]


@router.post("/{user_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def follow_rider(
    user_id: int,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.follow(current_user.id, user_id)
    except NotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{user_id}/unfollow", status_code=status.HTTP_204_NO_CONTENT)
def unfollow_rider(
    user_id: int,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    service.unfollow(current_user.id, user_id)


@router.post("/requests/{request_id}/accept", status_code=status.HTTP_204_NO_CONTENT)
def accept_request(
    request_id: int,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.accept(request_id, current_user.id)
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except NotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post("/requests/{request_id}/reject", status_code=status.HTTP_204_NO_CONTENT)
def reject_request(
    request_id: int,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        service.reject(request_id, current_user.id)
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except NotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.get("/requests", response_model=List[FollowRequestResponse])
def list_pending_requests(
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    result = []
    for f in service.list_pending_requests(current_user.id):
        from_user = service.user_repo.get_by_id(f.follower_id)
        if from_user is None:
            continue
        result.append(FollowRequestResponse(
            id=f.id, created_at=f.created_at,
            from_user=_rider_summary(service, from_user, current_user.id),
        ))
    return result


@router.get("/following", response_model=List[RiderSummaryResponse])
def list_following(
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    users = (service.user_repo.get_by_id(f.followee_id) for f in service.list_following(current_user.id))
    return [_rider_summary(service, u, current_user.id) for u in users if u]


@router.get("/followers", response_model=List[RiderSummaryResponse])
def list_followers(
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    users = (service.user_repo.get_by_id(f.follower_id) for f in service.list_followers(current_user.id))
    return [_rider_summary(service, u, current_user.id) for u in users if u]


def _feed_item_response(service: FollowService, item, viewer_id: int) -> FeedItemResponse:
    return FeedItemResponse(
        author=_rider_summary(service, item.author, viewer_id),
        route=RouteSummaryResponse(
            id=item.route.id, name=item.route.name, geojson=item.route.geojson,
            distance_km=item.route.distance_km, duration_minutes=item.route.duration_minutes,
            cover_image_url=item.route.cover_image_url, created_at=item.route.created_at,
        ),
    )


@router.get("/feed", response_model=List[FeedItemResponse])
def get_activity_feed(
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    """Rutas publicadas por la gente a la que sigues, más recientes
    primero — portada de la app."""
    return [
        _feed_item_response(service, item, current_user.id)
        for item in service.get_activity_feed(current_user.id)
    ]


@router.get("/feed/nearby", response_model=List[FeedItemResponse])
def get_nearby_feed(
    lat: float,
    lng: float,
    radius_km: float = 100,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    """Rutas públicas de cualquiera (no solo a quien sigues) cerca de
    `lat`/`lng`, más cercanas primero — pestaña "Cerca de ti", alternativa
    a "Siguiendo" en el feed de portada."""
    return [
        _feed_item_response(service, item, current_user.id)
        for item in service.get_nearby_feed(current_user.id, lat, lng, radius_km=radius_km)
    ]


@router.get("/{user_id}/profile", response_model=RiderProfileResponse)
def get_rider_profile(
    user_id: int,
    service: FollowService = Depends(get_service),
    current_user: UserModel = Depends(get_current_user),
):
    try:
        profile = service.get_rider_profile(user_id, current_user.id)
    except NotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    return RiderProfileResponse(
        id=profile.user.id, username=profile.user.username, avatar_url=profile.user.avatar_url,
        is_private=profile.user.is_private, follow_status=profile.follow_status,
        is_visible=profile.is_visible,
        current_motorbike=_motorbike_summary(profile.current_motorbike),
        recent_routes=[
            RouteSummaryResponse(
                id=r.id, name=r.name, geojson=r.geojson, distance_km=r.distance_km, duration_minutes=r.duration_minutes,
                cover_image_url=r.cover_image_url, created_at=r.created_at,
            )
            for r in profile.recent_routes
        ],
    )
