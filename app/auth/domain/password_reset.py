from dataclasses import dataclass
from datetime import datetime


@dataclass
class PasswordResetCode:
    id: int | None
    user_id: int
    # Hasheado igual que una contraseña (`get_password_hashed`/
    # `verify_password`, `app/shared/security.py`) — aunque solo dure 15
    # minutos, no hay motivo para guardarlo en claro.
    code_hash: str
    expires_at: datetime
    used: bool
    created_at: datetime
