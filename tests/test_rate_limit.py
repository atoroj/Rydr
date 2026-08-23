"""El resto de la suite corre con el limitador desactivado (ver
`tests/conftest.py` — todos los tests comparten la misma "IP" de
`TestClient`, así que dejarlo activo rompería tests que no tienen nada
que ver con rate limiting). Aquí se activa aposta, en un test aislado,
solo para comprobar que el límite estricto de los endpoints sensibles
(login, registro...) de verdad corta al superarlo — ver
`app/shared/rate_limit.py` y `app/auth/infrastructure/auth_router.py`.
"""
import pytest

from app.shared.rate_limit import limiter


@pytest.fixture
def rate_limiting_enabled():
    limiter.enabled = True
    limiter.reset()
    yield
    limiter.enabled = False


def test_login_endpoint_returns_429_after_five_attempts_per_minute(client, rate_limiting_enabled):
    client.post("/users/", json={
        "username": "ratelimited", "email": "ratelimited@test.com", "password": "pass1234", "role": "rider",
    })

    login_body = {"email": "ratelimited@test.com", "password": "wrong-password"}
    responses = [client.post("/auth/login", json=login_body) for _ in range(6)]

    # Las primeras 5 fallan por credenciales (401) — no por límite; la 6ª
    # tiene que cortar antes de mirar siquiera la contraseña.
    assert [r.status_code for r in responses[:5]] == [401] * 5
    assert responses[5].status_code == 429
