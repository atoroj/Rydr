"""Migraciones "ligeras" para el SQLite de desarrollo.

`Base.metadata.create_all` (ver app/main.py) crea tablas que no existen,
pero no añade columnas nuevas a tablas que ya existen — así que cada vez
que se añade un campo a un modelo (p.ej. `avatar_url`) hay que sumarlo aquí
también, o quien ya tenga un `.rydr.db` local se encuentra con un
"no such column" en el primer arranque. Nada de esto sustituye a una
herramienta de migraciones de verdad (Alembic) si el proyecto crece.
"""

from sqlalchemy import Engine


def _add_column_if_missing(engine: Engine, table: str, column: str, ddl: str) -> None:
    with engine.connect() as conn:
        existing = {row[1] for row in conn.exec_driver_sql(f"PRAGMA table_info({table})")}
        if column not in existing:
            conn.exec_driver_sql(f"ALTER TABLE {table} ADD COLUMN {ddl}")
            conn.commit()


def run_light_migrations(engine: Engine) -> None:
    _add_column_if_missing(engine, "users", "avatar_url", "avatar_url VARCHAR")
    _add_column_if_missing(engine, "users", "is_private", "is_private BOOLEAN DEFAULT 0")
    _add_column_if_missing(engine, "motorbike", "photo_url", "photo_url VARCHAR")
    _add_column_if_missing(engine, "motorbike", "is_current", "is_current BOOLEAN DEFAULT 0")
    _add_column_if_missing(engine, "motorbike", "year", "year INTEGER")
    _add_column_if_missing(engine, "routes", "cover_image_url", "cover_image_url VARCHAR")
