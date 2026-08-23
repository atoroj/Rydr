"""Dependencia FastAPI para saber "quién soy" a partir del JWT.

Hasta ahora los endpoints reciben el `user_id`/`author_id` directamente del
cliente (ver p.ej. app/motorbikes/infraestructure/motorbike_router.py) — es
decir, cualquiera puede decir "soy el usuario 7". Para Riders eso no vale:
aceptar/rechazar una solicitud de seguimiento tiene que depender de quién
ha iniciado sesión de verdad, no de un id que te pasas tú mismo en el body.
Esta dependencia se usa solo en los endpoints nuevos (uploads, riders,
`/users/me`) — no se ha retocado el resto de routers existentes.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.shared.database import get_db
from app.shared.security import ALGORITHM, SECRET_KEY
from app.users.infrastructure.user_model import UserModel

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

_CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="No se pudo validar la credencial",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> UserModel:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if email is None:
            raise _CREDENTIALS_ERROR
    except JWTError:
        raise _CREDENTIALS_ERROR

    user = db.query(UserModel).filter(UserModel.email == email).first()
    if user is None:
        raise _CREDENTIALS_ERROR
    return user
