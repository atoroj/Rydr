from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "sqlite:///.rydr.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
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
