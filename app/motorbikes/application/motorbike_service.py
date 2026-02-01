from app.motorbikes.domain.motorbike import Motorbike
from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy


class MotorbikeService:
    def __init__(self, repository: MotorbikeRepostiroy):
        self.repository = repository

    def create_motorbike(self, user_id: int, type: str, brand: str, model: str, alias: str):
        motorbike = Motorbike(id=None, user_id=user_id, type=type, brand=brand, model=model, alias=alias)
        return self.repository.save(motorbike)

    def get_motorbikes_by_user_id(self, user_id: int):
        return self.repository.get_all_by_user_id(user_id)

    def get_motorbike_by_id(self, id: int):
        return self.repository.get_by_id(id)

    def get_motorbikes(self):
        return self.repository.get_all()