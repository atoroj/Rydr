from dataclasses import dataclass

@dataclass
class Auth:
    email: str
    # `None` para una cuenta creada solo por Google — nunca puso
    # contraseña propia, así que nunca podrá pasar por `login()` normal.
    password_hash: str | None
    role: str