from app.motorbikes.domain.motorbike import Motorbike, MotorBykeType
from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy


class MotorbikeService:
    def __init__(self, repository: MotorbikeRepostiroy):
        self.repository = repository

    def create_motorbike(self, user_id: int, type: MotorBykeType, brand: str, model: str, cc: int, alias: str | None, photo_url: str | None = None, year: int | None = None) -> Motorbike:
        motorbike = Motorbike(id=None, user_id=user_id, type=type, brand=brand, model=model, cc=cc, alias=alias, photo_url=photo_url, year=year)
        return self.repository.save(motorbike)

    def get_motorbikes_by_user_id(self, user_id: int):
        return self.repository.get_all_by_user_id(user_id)

    def get_motorbike_by_id(self, id: int):
        return self.repository.get_by_id(id)

    def get_motorbikes(self):
        return self.repository.get_all()

    def set_current(self, user_id: int, motorbike_id: int) -> Motorbike:
        return self.repository.set_current(user_id, motorbike_id)

    def update_motorbike(
        self, motorbike_id: int, user_id: int,
        type: MotorBykeType | None = None, brand: str | None = None, model: str | None = None,
        cc: int | None = None, alias: str | None = None, photo_url: str | None = None,
        year: int | None = None,
    ) -> Motorbike:
        return self.repository.update(
            motorbike_id, user_id, type=type, brand=brand, model=model,
            cc=cc, alias=alias, photo_url=photo_url, year=year,
        )

    def delete_motorbike(self, motorbike_id: int, user_id: int) -> None:
        self.repository.delete(motorbike_id, user_id)