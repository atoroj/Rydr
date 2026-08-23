"""Migraciones "ligeras", portables entre SQLite (desarrollo local) y
Postgres (servidor, ver docker-compose.yml).

`Base.metadata.create_all` (ver app/main.py) crea tablas que no existen,
pero no añade columnas nuevas a tablas que ya existen — así que cada vez
que se añade un campo a un modelo (p.ej. `avatar_url`) hay que sumarlo aquí
también, o quien ya tenga una base de datos de antes se encuentra con un
"no such column"/"column does not exist" en el primer arranque tras
actualizar. Esto corre en CADA arranque (ver `run_light_migrations` en
app/main.py) — tanto la primera vez (base de datos nueva, sin nada que
hacer) como después de cada actualización de código que añada una
columna a un modelo ya existente, da igual si es SQLite o Postgres.
Nada de esto sustituye a una herramienta de migraciones de verdad
(Alembic) si el proyecto crece.

Dos cosas para que la misma sentencia sirva en los dos motores:
- Se usa `inspect(engine).get_columns(...)` (de SQLAlchemy, agnóstico del
  motor) en vez de `PRAGMA table_info(...)`, que es sintaxis específica
  de SQLite y no existe en Postgres.
- Los DDL usan `TRUE`/`FALSE` en vez de `1`/`0` como valor por defecto de
  columnas booleanas (Postgres no acepta `1`/`0` ahí; SQLite sí entiende
  `TRUE`/`FALSE` desde hace años) y `TIMESTAMP` en vez de `DATETIME`
  (Postgres no tiene el tipo `DATETIME`; SQLite acepta cualquier nombre
  de tipo sin más, por "type affinity").
"""

from sqlalchemy import Engine, inspect


def _add_column_if_missing(engine: Engine, table: str, column: str, ddl: str) -> None:
    existing = {col["name"] for col in inspect(engine).get_columns(table)}
    if column not in existing:
        with engine.connect() as conn:
            conn.exec_driver_sql(f"ALTER TABLE {table} ADD COLUMN {ddl}")
            conn.commit()


def run_light_migrations(engine: Engine) -> None:
    _add_column_if_missing(engine, "users", "avatar_url", "avatar_url VARCHAR")
    _add_column_if_missing(engine, "users", "is_private", "is_private BOOLEAN DEFAULT FALSE")
    _add_column_if_missing(engine, "motorbike", "photo_url", "photo_url VARCHAR")
    _add_column_if_missing(engine, "motorbike", "is_current", "is_current BOOLEAN DEFAULT FALSE")
    _add_column_if_missing(engine, "motorbike", "year", "year INTEGER")
    _add_column_if_missing(engine, "routes", "cover_image_url", "cover_image_url VARCHAR")
    _add_column_if_missing(engine, "meetup_participants", "last_lat", "last_lat FLOAT")
    _add_column_if_missing(engine, "meetup_participants", "last_lng", "last_lng FLOAT")
    _add_column_if_missing(engine, "meetup_participants", "last_location_at", "last_location_at TIMESTAMP")
    _add_column_if_missing(engine, "track_points", "is_segment_start", "is_segment_start BOOLEAN DEFAULT FALSE")
    _add_column_if_missing(engine, "meetups", "location_hidden", "location_hidden BOOLEAN DEFAULT FALSE")
    _add_column_if_missing(engine, "meetups", "approximate_area", "approximate_area VARCHAR")
    _add_column_if_missing(engine, "meetups", "location_revealed", "location_revealed BOOLEAN DEFAULT FALSE")
    _add_column_if_missing(engine, "users", "google_id", "google_id VARCHAR")
    _add_column_if_missing(engine, "routes", "start_lat", "start_lat FLOAT")
    _add_column_if_missing(engine, "routes", "start_lng", "start_lng FLOAT")
