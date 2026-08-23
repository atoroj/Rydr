"""Envío de correo transaccional vía Resend — una sola llamada HTTP (usa
`requests`, ya dependencia por `google-auth`), sin SDK ni SMTP de por
medio. Solo se usa por ahora para el código de restablecer contraseña
(ver `AuthService.request_password_reset`).
"""

import os

import requests
from dotenv import load_dotenv

load_dotenv()

RESEND_API_KEY = os.getenv("RESEND_API_KEY")
# Placeholder hasta que verifiques un dominio propio en Resend — con la
# cuenta gratuita, "onboarding@resend.dev" es el único remitente que
# funciona sin verificar nada.
RESEND_FROM_EMAIL = os.getenv("RESEND_FROM_EMAIL", "Rydr <onboarding@resend.dev>")

RESEND_API_URL = "https://api.resend.com/emails"


def send_email(to: str, subject: str, html: str) -> None:
    """No lanza si falla el envío — un email que no llega no debe tumbar
    la petición que lo pidió (p. ej. `request_password_reset`, que
    siempre responde 204 igual para no filtrar qué emails existen). El
    fallo se traga en silencio a propósito; si hiciera falta detectarlo
    de verdad, este es el sitio para mandarlo a un servicio de logs."""
    if not RESEND_API_KEY:
        return
    try:
        requests.post(
            RESEND_API_URL,
            headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
            json={"from": RESEND_FROM_EMAIL, "to": [to], "subject": subject, "html": html},
            timeout=10,
        )
    except requests.RequestException:
        pass
