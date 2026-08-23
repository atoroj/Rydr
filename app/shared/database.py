import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

# SQLite en local por defecto (cero configuración para desarrollar) — en
# el servidor, `docker-compose.yml` pasa un DATABASE_URL de Postgres por
# variable de entorno. Antes esto estaba fijo a SQLite sin más, ignorando
# la variable de entorno que ya existía en `.env` sin usarse. El valor
# por defecto es EXACTAMENTE el que ya se usaba a mano (mismo archivo
# `.rydr.db` que ya tienes con datos de desarrollo) — no cambia nada si
# no defines `DATABASE_URL`.
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///.rydr.db")

# `check_same_thread` es un parámetro del driver de SQLite (permite usar
# la misma conexión desde el hilo que atiende cada petición de FastAPI,
# distinto del hilo que la abrió) — no existe para psycopg2/Postgres, y
# pasárselo siempre haría fallar la conexión contra Postgres.
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine)

Base = declarative_base()

# Dependencia para obtener la sesión de la BD en cada petición
def get_db():
    """Genera una sesión de base de datos y garantiza que se cierre después de su uso.

    Esta función generadora crea una sesión nueva a partir de SessionLocal, la cede
    para su uso (por ejemplo como dependencia en FastAPI) y asegura que la sesión
    se cierre cuando el consumidor termine o si ocurre una excepción.

    Yields:
        sqlalchemy.orm.Session: Una instancia activa de sesión de la base de datos.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
