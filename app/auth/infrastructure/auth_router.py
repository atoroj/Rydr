from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from app.shared.database import get_db
from app.shared.rate_limit import limiter
from app.auth.application.auth_dto import ForgotPasswordRequest, GoogleLoginRequest, LoginRequest, ResetPasswordRequest
# Imports de infraestructura para "montar" las piezas
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.application.user_service import UserService
from app.auth.infrastructure.adapters.user_adapter import LocalUserAdapter
from app.auth.infrastructure.sql_password_reset_repository import SqlAlchemyPasswordResetRepository
from app.auth.application.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])

def get_auth_service(db: Session = Depends(get_db)):
    # 1. Montamos Users
    user_repo = SqlAlchemyUserRepository(db)
    user_service = UserService(user_repo)

    # 2. Montamos adapters
    adapter = LocalUserAdapter(user_service)

    # 3. Montamos Auth con el Adaptador
    password_reset_repo = SqlAlchemyPasswordResetRepository(db)
    return AuthService(adapter, password_reset_repo)

# Todos los endpoints de este router están entre los más golpeados por
# fuerza bruta/abuso (probar contraseñas, crear cuentas en bucle, agotar
# el crédito de emails de restablecer) — de ahí el límite más estricto
# que el global de 60/min (ver app/shared/rate_limit.py), aparte del
# `request: Request` que pide `@limiter.limit` para identificar la IP.
@router.post("/login")
@limiter.limit("5/minute")
def login(request: Request, body: LoginRequest, service: AuthService = Depends(get_auth_service)):
    token = service.login(body.email, body.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")
    return {"access_token": token, "token_type": "bearer"}

# Login nativo con Google: la app (SDK de Google Sign-In en iOS) hace el
# login in situ y consigue un ID token firmado por Google — aquí solo se
# verifica ese token y se firma el JWT propio, mismo formato que
# `/auth/login`. Nada de flujo de redirección web (lo que había antes,
# con `fastapi_sso`): eso es para apps web, no sirve para una app nativa.
@router.post("/google")
@limiter.limit("5/minute")
def login_with_google(request: Request, body: GoogleLoginRequest, service: AuthService = Depends(get_auth_service)):
    token = service.login_with_google(body.id_token)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token de Google inválido")
    return {"access_token": token, "token_type": "bearer"}

# Siempre responde 204, exista o no ese email — si devolviera 404 para
# los que no existen, cualquiera podría usar este endpoint para
# comprobar qué emails están registrados en la app.
@router.post("/forgot-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("5/minute")
def forgot_password(request: Request, body: ForgotPasswordRequest, service: AuthService = Depends(get_auth_service)):
    service.request_password_reset(body.email)
    return None

@router.post("/reset-password")
@limiter.limit("5/minute")
def reset_password(request: Request, body: ResetPasswordRequest, service: AuthService = Depends(get_auth_service)):
    ok = service.reset_password(body.email, body.code, body.new_password)
    if not ok:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código inválido o caducado")
    return {"ok": True}
