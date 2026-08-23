import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.shared.database import Base, get_db
from app.shared.rate_limit import limiter

# `TestClient` no hace peticiones de red de verdad: todas comparten la
# misma "IP" (`get_remote_address` ve siempre "testclient"), así que sin
# esto los límites por IP de app/shared/rate_limit.py se agotarían entre
# tests sin que eso tenga nada que ver con lo que cada test comprueba de
# verdad — ver el propio módulo para el porqué de cada límite.
limiter.enabled = False

# 1. Base de datos en memoria (se borra al terminar el test)
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
TestingSessionLocal = sessionmaker(autoflush=False, bind=engine)

# 2. Fixture: Prepara la BD antes de cada test
@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        # Borra las tablas al terminar
        Base.metadata.drop_all(bind=engine)
        
@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            db_session.close()
    
    # Le decimos a FastAPI que use nuestra BD de prueba
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as c:
        yield c