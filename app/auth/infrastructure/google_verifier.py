"""Verificación del ID token que manda el SDK nativo de Google Sign-In
(iOS) — separado de `auth_service.py` para poder sustituirlo fácilmente
en los tests (no se puede generar un token firmado de verdad por Google
en un test) y porque envolver `google-auth` aquí, en infraestructura, es
lo que le toca en la arquitectura hexagonal del proyecto: es el único
sitio que sabe que la verificación es "de Google" en concreto.
"""

import os
from dataclasses import dataclass

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token


@dataclass
class GoogleAccount:
    email: str
    name: str | None
    google_id: str
    avatar_url: str | None


class InvalidGoogleTokenError(Exception):
    """El ID token no verifica (firma, expiración, audience...) o no
    tiene el email confirmado por Google — 401 en el router."""


def verify_google_id_token(id_token: str) -> GoogleAccount:
    client_id = os.getenv("GOOGLE_CLIENT_ID")
    try:
        # `verify_oauth2_token` comprueba firma, expiración e issuer, y
        # además que el "aud" del token sea exactamente `client_id` — así
        # un token válido pero emitido para OTRA app no cuela aquí. Todos
        # los fallos de verificación de esta función salen como
        # `ValueError` (token expirado, firma inválida, audience que no
        # coincide...).
        payload = google_id_token.verify_oauth2_token(
            id_token, google_requests.Request(), audience=client_id
        )
    except ValueError as e:
        raise InvalidGoogleTokenError(str(e)) from e

    if not payload.get("email_verified", False):
        raise InvalidGoogleTokenError("Google no ha verificado este email")

    return GoogleAccount(
        email=payload["email"],
        name=payload.get("name"),
        google_id=payload["sub"],
        avatar_url=payload.get("picture"),
    )
