import secrets
from datetime import datetime, timedelta

from app.auth.domain.password_reset import PasswordResetCode
from app.auth.domain.password_reset_repository import PasswordResetRepository
from app.auth.domain.ports import UserProviderPort
from app.auth.infrastructure.google_verifier import InvalidGoogleTokenError, verify_google_id_token
from app.shared.email import send_email
from app.shared.security import verify_password, get_password_hashed, create_access_token

# El código dura poco a propósito — es de un solo uso y se manda por
# email, no hace falta que aguante más que lo que tarda alguien en leer
# el correo y volver a la app.
RESET_CODE_EXPIRY_MINUTES = 15

class AuthService:
    def __init__(self, user_provider: UserProviderPort, password_reset_repo: PasswordResetRepository):
        self.user_provider = user_provider
        self.password_reset_repo = password_reset_repo

    def login(self, email: str, password: str):
        user = self.user_provider.get_user_by_email(email)
        # `password_hash` es `None` en una cuenta creada solo por
        # Google (nunca puso contraseña propia) — sin este chequeo,
        # `verify_password` peta con un `AttributeError` en vez de
        # devolver "credenciales inválidas" como cualquier otro fallo.
        if not user or not user.password_hash or not verify_password(password, user.password_hash):
            return None

        return create_access_token(data={"sub": user.email, "role": user.role})

    def login_with_google(self, id_token: str) -> str | None:
        """Verifica el ID token que manda el SDK nativo (iOS), busca o
        crea la cuenta correspondiente, y firma el mismo tipo de JWT que
        `login()` — mismos claims, así que el resto de la app (validación
        de token, `/users/me`...) no tiene que saber por qué camino
        entró alguien."""
        try:
            account = verify_google_id_token(id_token)
        except InvalidGoogleTokenError:
            return None

        user = self.user_provider.get_or_create_google_user(
            account.email, account.google_id, account.avatar_url
        )
        return create_access_token(data={"sub": user.email, "role": user.role})

    def request_password_reset(self, email: str) -> None:
        """Nunca informa de si el email existe o no (el router siempre
        responde 204 igual) — si existe, genera un código de 6 dígitos,
        invalida cualquier código anterior sin usar de ese usuario, y lo
        manda por correo. Si no existe, no hace nada."""
        user = self.user_provider.get_user_by_email(email)
        if user is None:
            return

        code = f"{secrets.randbelow(1_000_000):06d}"
        self.password_reset_repo.invalidate_all_for_user(user.id)
        self.password_reset_repo.save(PasswordResetCode(
            id=None,
            user_id=user.id,
            code_hash=get_password_hashed(code),
            expires_at=datetime.now() + timedelta(minutes=RESET_CODE_EXPIRY_MINUTES),
            used=False,
            created_at=datetime.now(),
        ))
        send_email(
            to=email,
            subject="Tu código para restablecer la contraseña de Rydr",
            html=(
                f"<p>Usa este código para elegir una contraseña nueva. "
                f"Caduca en {RESET_CODE_EXPIRY_MINUTES} minutos.</p>"
                f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px'>{code}</p>"
                f"<p>Si no has pedido esto, puedes ignorar el mensaje.</p>"
            ),
        )

    def reset_password(self, email: str, code: str, new_password: str) -> bool:
        """Devuelve False si el código no vale (caducado, incorrecto, ya
        usado, o email que no existe) — el router lo traduce a 400."""
        user = self.user_provider.get_user_by_email(email)
        if user is None:
            return False

        active_code = self.password_reset_repo.get_active_for_user(user.id)
        if active_code is None:
            return False
        if active_code.expires_at < datetime.now():
            return False
        if not verify_password(code, active_code.code_hash):
            return False

        self.password_reset_repo.mark_used(active_code.id)
        self.user_provider.update_password(user.id, new_password)
        return True
