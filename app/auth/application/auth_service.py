from app.auth.domain.ports import UserProviderPort
from app.auth.infrastructure.google_verifier import InvalidGoogleTokenError, verify_google_id_token
from app.shared.security import verify_password, create_access_token

class AuthService:
    def __init__(self, user_provider: UserProviderPort):
        self.user_provider = user_provider

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
