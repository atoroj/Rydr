from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.shared.database import get_db
from app.auth.application.auth_dto import GoogleLoginRequest, LoginRequest
# Imports de infraestructura para "montar" las piezas
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.application.user_service import UserService
from app.auth.infrastructure.adapters.user_adapter import LocalUserAdapter
from app.auth.application.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])

def get_auth_service(db: Session = Depends(get_db)):
    # 1. Montamos Users
    user_repo = SqlAlchemyUserRepository(db)
    user_service = UserService(user_repo)

    # 2. Montamos adapters
    adapter = LocalUserAdapter(user_service)

    # 3. Montamos Auth con el Adaptador
    return AuthService(adapter)

@router.post("/login")
def login(request: LoginRequest, service: AuthService = Depends(get_auth_service)):
    token = service.login(request.email, request.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")
    return {"access_token": token, "token_type": "bearer"}

# Login nativo con Google: la app (SDK de Google Sign-In en iOS) hace el
# login in situ y consigue un ID token firmado por Google — aquí solo se
# verifica ese token y se firma el JWT propio, mismo formato que
# `/auth/login`. Nada de flujo de redirección web (lo que había antes,
# con `fastapi_sso`): eso es para apps web, no sirve para una app nativa.
@router.post("/google")
def login_with_google(request: GoogleLoginRequest, service: AuthService = Depends(get_auth_service)):
    token = service.login_with_google(request.id_token)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token de Google inválido")
    return {"access_token": token, "token_type": "bearer"}
