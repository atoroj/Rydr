from fastapi import FastAPI
from app.shared.database import Base, engine
from app.users.infrastructure.user_router import router as user_router
from app.auth.infrastructure.auth_router import router as auth_router
# Importante: Importar el modelo para que SQLAlchemy sepa que existe al crear tablas
from app.users.infrastructure.user_model import UserModel

# Crear tablas (Solo para desarrollo rápido)
Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(user_router)
app.include_router(auth_router)