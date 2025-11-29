from fastapi import FastAPI
from app.shared.database import Base, engine
from app.users.infrastructure.router import router as user_router
# Importante: Importar el modelo para que SQLAlchemy sepa que existe al crear tablas
from app.users.infrastructure.models import UserModel

# Crear tablas (Solo para desarrollo rápido)
Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(user_router)