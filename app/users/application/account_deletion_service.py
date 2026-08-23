from app.meetups.domain.meetup_repository import MeetupRepository
from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy
from app.riders.domain.follow_repository import FollowRepository
from app.rides.domain.ride_repository import RideRepository
from app.routes.domain.route_repository import RouteRepository
from app.shared.errors import NotFoundError
from app.shared.uploads_router import delete_upload
from app.users.domain.user_repository import UserRepository


class AccountDeletionService:
    """Borra una cuenta y todo lo que le pertenece — mismo espíritu que
    `FollowService`: coordina varios módulos porque el resultado final
    ("no queda ni rastro de este usuario") no le pertenece a uno solo.

    Orden pensado a propósito: las quedadas organizadas se borran ANTES
    de mirar `list_joined_by` — `meetup_repo.delete` ya limpia sus
    filas de participante (incluida la del propio organizador, que
    `MeetupService.create` apunta como participante también), así que
    para cuando se pide `list_joined_by` esas ya no aparecen y no hay
    que distinguirlas a mano de las que solo se han apuntado."""

    def __init__(
        self,
        user_repo: UserRepository,
        motorbike_repo: MotorbikeRepostiroy,
        ride_repo: RideRepository,
        route_repo: RouteRepository,
        meetup_repo: MeetupRepository,
        follow_repo: FollowRepository,
    ):
        self.user_repo = user_repo
        self.motorbike_repo = motorbike_repo
        self.ride_repo = ride_repo
        self.route_repo = route_repo
        self.meetup_repo = meetup_repo
        self.follow_repo = follow_repo

    def delete_account(self, user_id: int) -> None:
        user = self.user_repo.get_by_id(user_id)
        if user is None:
            raise NotFoundError("Usuario no encontrado")

        for motorbike in self.motorbike_repo.get_all_by_user_id(user_id):
            delete_upload(motorbike.photo_url)
            self.motorbike_repo.delete(motorbike.id, user_id)

        # `ride_repo.delete` no comprueba dueño (a diferencia del resto de
        # repos de este método) — ya viene filtrado por `get_by_rider_id`.
        for ride in self.ride_repo.get_by_rider_id(user_id):
            self.ride_repo.delete(ride.id)

        for route in self.route_repo.get_all_by_author(user_id):
            delete_upload(route.cover_image_url)
            self.route_repo.delete(route.id, user_id)

        for meetup in self.meetup_repo.list_by_organizer(user_id):
            self.meetup_repo.delete(meetup.id, user_id)

        # Lo que quede en `list_joined_by` a estas alturas es, por
        # construcción, solo lo que no organizaba (ver docstring).
        for meetup in self.meetup_repo.list_joined_by(user_id):
            self.meetup_repo.remove_participant(meetup.id, user_id)

        self.follow_repo.delete_all_for_user(user_id)

        delete_upload(user.avatar_url)
        self.user_repo.delete(user_id)
