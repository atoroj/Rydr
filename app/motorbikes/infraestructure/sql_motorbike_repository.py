from typing import List

from sqlalchemy.orm import Session

from app.motorbikes.domain.motorbike_repository import MotorbikeRepostiroy
from app.motorbikes.domain.motorbike import Motorbike
from app.motorbikes.infraestructure.motorbike_model import MotorbikeModel
from app.shared.errors import NotFoundError


class SqlAlchemyMotorbikeRepository(MotorbikeRepostiroy):
    def __init__(self, db: Session):
        self.db = db

    def _to_domain(self, motorbike_db: MotorbikeModel) -> Motorbike:
        return Motorbike(
            id=motorbike_db.id, user_id=motorbike_db.user_id, type=motorbike_db.type,
            brand=motorbike_db.brand, model=motorbike_db.model,
            cc=motorbike_db.cc, alias=motorbike_db.alias,
            photo_url=motorbike_db.photo_url, is_current=bool(motorbike_db.is_current),
            year=motorbike_db.year,
        )

    def save(self, motorbike: Motorbike):
        type_value = motorbike.type.value if hasattr(motorbike.type, "value") else motorbike.type
        motorbike_db = MotorbikeModel(user_id=motorbike.user_id, type=type_value,
                                      brand=motorbike.brand, model=motorbike.model,
                                      cc=motorbike.cc, alias=motorbike.alias,
                                      photo_url=motorbike.photo_url, is_current=motorbike.is_current,
                                      year=motorbike.year)
        self.db.add(motorbike_db)
        self.db.commit()
        self.db.refresh(motorbike_db)
        return self._to_domain(motorbike_db)

    def get_all_by_user_id(self, userId: int) -> List[Motorbike]:
        motorbikes_db = self.db.query(MotorbikeModel).filter(MotorbikeModel.user_id == userId)
        return [self._to_domain(motorbike) for motorbike in motorbikes_db]

    def get_all(self) -> List[Motorbike]:
        motorbikes_db = self.db.query(MotorbikeModel).all()
        return [self._to_domain(motorbike) for motorbike in motorbikes_db]

    def get_by_id(self, id: int) -> Motorbike | None:
        motorbike_db = self.db.query(MotorbikeModel).filter(MotorbikeModel.id == id).first()
        if motorbike_db is None:
            return None
        return self._to_domain(motorbike_db)

    def set_current(self, user_id: int, motorbike_id: int) -> Motorbike:
        target_db = self.db.query(MotorbikeModel).filter(
            MotorbikeModel.id == motorbike_id, MotorbikeModel.user_id == user_id
        ).first()
        if target_db is None:
            raise NotFoundError("Moto no encontrada para este usuario")

        # Solo puede haber una moto "actual" por usuario: desmarca el resto.
        self.db.query(MotorbikeModel).filter(
            MotorbikeModel.user_id == user_id, MotorbikeModel.id != motorbike_id
        ).update({MotorbikeModel.is_current: False})

        target_db.is_current = True
        self.db.commit()
        self.db.refresh(target_db)
        return self._to_domain(target_db)

    def update(self, motorbike_id: int, user_id: int, **fields) -> Motorbike:
        target_db = self.db.query(MotorbikeModel).filter(
            MotorbikeModel.id == motorbike_id, MotorbikeModel.user_id == user_id
        ).first()
        if target_db is None:
            raise NotFoundError("Moto no encontrada para este usuario")

        for key, value in fields.items():
            if value is None:
                continue
            if key == "type" and hasattr(value, "value"):
                value = value.value
            setattr(target_db, key, value)

        self.db.commit()
        self.db.refresh(target_db)
        return self._to_domain(target_db)

    def delete(self, motorbike_id: int, user_id: int) -> None:
        target_db = self.db.query(MotorbikeModel).filter(
            MotorbikeModel.id == motorbike_id, MotorbikeModel.user_id == user_id
        ).first()
        if target_db is None:
            raise NotFoundError("Moto no encontrada para este usuario")
        self.db.delete(target_db)
        self.db.commit()
