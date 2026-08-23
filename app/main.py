import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.shared.database import Base, engine
from app.shared.migrations import run_light_migrations
from app.shared.uploads_router import UPLOAD_DIR, router as uploads_router
from app.users.infrastructure.user_router import router as user_router
from app.auth.infrastructure.auth_router import router as auth_router
from app.motorbikes.infraestructure.motorbike_router import router as motorbike_router
from app.rides.infrastructure.ride_router import router as ride_router
from app.routes.infrastructure.route_router import router as route_router
from app.riders.infrastructure.follow_router import router as follow_router
from app.meetups.infrastructure.meetup_router import router as meetup_router
from app.badges.infrastructure.badge_router import router as badge_router
# Importar modelos para que SQLAlchemy los registre al crear tablas
from app.users.infrastructure.user_model import UserModel
from app.motorbikes.infraestructure.motorbike_model import MotorbikeModel
from app.rides.infrastructure.ride_model import RideModel, TrackPointModel
from app.routes.infrastructure.route_model import RouteModel
from app.riders.infrastructure.follow_model import FollowModel
from app.meetups.infrastructure.meetup_model import MeetupModel, MeetupParticipantModel
from app.auth.infrastructure.password_reset_model import PasswordResetCodeModel

# Crea las tablas que falten (no toca las que ya existen).
Base.metadata.create_all(bind=engine)
# `run_light_migrations` añade a mano las columnas que se han ido
# sumando a modelos ya existentes (create_all no altera tablas ya
# creadas) — portable entre SQLite y Postgres (ver
# app/shared/migrations.py), así que corre siempre: hace falta tanto la
# primera vez en un servidor nuevo como en cada actualización posterior
# que añada una columna.
run_light_migrations(engine)

load_dotenv()

app = FastAPI()

# `ALLOWED_ORIGINS` — lista separada por comas, vacía por defecto (ver
# .env.example). CORS es cosa del navegador: la app iOS no lo sufre ni se
# beneficia de él, así que esto es higiene razonable para si algún día
# hay un cliente web, no la protección real de esta API (eso lo hace el
# JWT, y contra fuerza bruta/abuso, el rate limiting).
allowed_origins = [origin.strip() for origin in os.getenv("ALLOWED_ORIGINS", "").split(",") if origin.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.include_router(user_router)
app.include_router(auth_router)
app.include_router(motorbike_router)
app.include_router(ride_router)
app.include_router(route_router)
app.include_router(uploads_router)
app.include_router(follow_router)
app.include_router(meetup_router)
app.include_router(badge_router)
