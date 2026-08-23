"""Limitador de peticiones por IP (`slowapi`, sobre `limits`/Redis-menos
in-memory por defecto — de sobra para el tráfico que tiene esta app).

Un límite global moderado para toda la API (ver `default_limits` donde se
usa este `limiter` en `app/main.py`) más límites más estrictos, puestos a
mano con `@limiter.limit(...)`, en los endpoints más golpeados por fuerza
bruta o abuso: login, login con Google, registro, y las dos mitades de
restablecer contraseña.

Para que `get_remote_address` vea la IP real del cliente (y no siempre la
de Caddy, que es quien conecta de verdad con el backend en Docker) el
`Dockerfile` arranca uvicorn con `--proxy-headers
--forwarded-allow-ips='*'` — seguro aquí porque el backend no está
expuesto al exterior, solo Caddy puede llegarle directamente (ver
docker-compose.yml: "backend" no publica ningún puerto).

En los tests (`tests/conftest.py`) se desactiva (`limiter.enabled =
False`) — si no, todos los tests comparten la misma "IP" (`TestClient` no
hace peticiones de red de verdad) y unos cuantos tests seguidos que creen
usuarios o inicien sesión agotarían el límite entre ellos, sin que eso
tenga nada que ver con lo que cada test intenta comprobar.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])
