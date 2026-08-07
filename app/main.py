from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.shared.database import Base, engine
from app.users.infrastructure.user_router import router as user_router
from app.auth.infrastructure.auth_router import router as auth_router
from app.motorbikes.infraestructure.motorbike_router import router as motorbike_router
from app.rides.infrastructure.ride_router import router as ride_router
from app.routes.infrastructure.route_router import router as route_router
# Importar modelos para que SQLAlchemy los registre al crear tablas
from app.users.infrastructure.user_model import UserModel
from app.motorbikes.infraestructure.motorbike_model import MotorbikeModel
from app.rides.infrastructure.ride_model import RideModel, TrackPointModel
from app.routes.infrastructure.route_model import RouteModel

# Crear tablas (Solo para desarrollo rápido)
Base.metadata.create_all(bind=engine)

app = FastAPI()

# Permite peticiones desde Flutter Web (localhost) y cualquier origen en desarrollo
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(user_router)
app.include_router(auth_router)
app.include_router(motorbike_router)
app.include_router(ride_router)
app.include_router(route_router)