from dataclasses import dataclass

@dataclass
class User:
    id: int | None
    email: str
    username: str
    password: str | None
    role: str
    avatar_url: str | None = None
    is_private: bool = False
    # Solo tiene valor si la cuenta se creó (o se enlazó) con "Continuar
    # con Google" — ver `UserService.get_or_create_google_user`. Una
    # cuenta así puede no tener `password` (None): entró siempre por
    # Google, nunca puso una contraseña propia.
    google_id: str | None = None