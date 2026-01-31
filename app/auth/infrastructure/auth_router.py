from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.shared.database import get_db
from app.auth.application.auth_dto import LoginRequest
# Imports de infraestructura para "montar" las piezas
from app.users.infrastructure.sql_user_repository import SqlAlchemyUserRepository
from app.users.application.user_service import UserService
from app.auth.infrastructure.adapters.user_adapter import LocalUserAdapter
from app.auth.application.auth_service import AuthService

# Para Google OAuth
from fastapi_sso.sso.google import GoogleSSO

GOOGLE_CLIENT_ID = "tu-client-id"
GOOGLE_CLIENT_SECRET = "tu-client-secret"
google_sso = GoogleSSO(GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, "http://localhost:8000/auth/google/callback")

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

# --- LOGIN GOOGLE: PASO 1 (Redirigir a Google) ---
@router.get("/google/login")
async def google_login():
    return await google_sso.get_login_redirect()

# --- LOGIN GOOGLE: PASO 2 (Callback de Google) ---
@router.get("/google/callback")
async def google_callback(request, service: AuthService = Depends(get_auth_service)):
    # 1. Obtener info de Google
    user_google = await google_sso.verify_and_process(request)
    
    # 2. Procesar lógica de negocio (buscar/crear usuario y generar JWT)
    jwt_token = await service.login_with_google(user_google.email, user_google.display_name)
    
    return {"access_token": jwt_token, "token_type": "bearer"}