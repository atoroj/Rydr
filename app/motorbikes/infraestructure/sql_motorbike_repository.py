from typing import List

from sqlalchemy.orm import Session

from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy
from app.motorbikes.domain.motorbike import Motorbike
from app.motorbikes.infraestructure.motorbike_model import MotorbikeModel


class SqlAlchemyMotorbikeRepository(MotorbikeRepostiroy):
    def __init__(self, db: Session):
        self.db = db

    def save(self, motorbike: Motorbike):
        type_value = motorbike.type.value if hasattr(motorbike.type, "value") else motorbike.type
        motorbike_db = MotorbikeModel(user_id=motorbike.user_id, type=type_value,
                                      brand=motorbike.brand, model=motorbike.model,
                                      cc=motorbike.cc, alias=motorbike.alias)
        self.db.add(motorbike_db)
        self.db.commit()
        self.db.refresh(motorbike_db)
        return Motorbike(id=motorbike_db.id, user_id=motorbike.user_id,
                         type=motorbike.type, brand=motorbike.brand,
                         model=motorbike.model, cc=motorbike.cc, alias=motorbike.alias)

    def get_all_by_user_id(self, userId: int) -> List[Motorbike]:
        motorbikes_db = self.db.query(MotorbikeModel).filter(MotorbikeModel.user_id == userId)
        return [
            Motorbike(id=motorbike.id, user_id=motorbike.user_id, type=motorbike.type,
                                      brand=motorbike.brand, model=motorbike.model,
                                      cc=motorbike.cc, alias=motorbike.alias)
            for motorbike in motorbikes_db
        ]

    def get_all(self) -> List[Motorbike]:
        motorbikes_db = self.db.query(MotorbikeModel).all()
        return [
            Motorbike(id=motorbike.id, user_id=motorbike.user_id, type=motorbike.type,
                                      brand=motorbike.brand, model=motorbike.model,
                                      cc=motorbike.cc, alias=motorbike.alias)
            for motorbike in motorbikes_db
        ]

    def get_by_id(self, id: int) -> Motorbike | None:
        motorbike_db = self.db.query(MotorbikeModel).filter(MotorbikeModel.id == id).first()
        if motorbike_db is None:
            return None
        return Motorbike(id=motorbike_db.id, user_id=motorbike_db.user_id, type=motorbike_db.type,
                         brand=motorbike_db.brand, model=motorbike_db.model,
                         cc=motorbike_db.cc, alias=motorbike_db.alias)