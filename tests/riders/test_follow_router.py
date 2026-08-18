# Primeros tests para `riders`/follow — no había ninguno todavía. Se
# centran en la corrección de código concreta hecha en el refactor: antes
# de introducir `NotFoundError` (ver `app/shared/errors.py`), estos
# endpoints devolvían 400 en vez de 404 cuando el usuario/solicitud
# objetivo no existía, porque `follow_service.py` usaba la misma
# `ValueError` para "no encontrado" que para errores de validación
# genuinos (p. ej. "no puedes seguirte a ti mismo") y el router no podía
# distinguir los dos casos.


def register_and_login(client, suffix: str) -> tuple[int, str]:
    user = client.post("/users/", json={
        "username": f"rider{suffix}", "email": f"rider{suffix}@test.com",
        "password": "pass1234", "role": "rider",
    }).json()
    token = client.post("/auth/login", json={
        "email": f"rider{suffix}@test.com", "password": "pass1234",
    }).json()["access_token"]
    return user["id"], token


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_follow_nonexistent_user_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/riders/9999/follow", headers=auth_headers(token))
    assert response.status_code == 404


def test_follow_self_returns_400_not_404(client):
    user_id, token = register_and_login(client, "1")
    response = client.post(f"/riders/{user_id}/follow", headers=auth_headers(token))
    assert response.status_code == 400


def test_accept_nonexistent_request_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/riders/requests/9999/accept", headers=auth_headers(token))
    assert response.status_code == 404


def test_reject_nonexistent_request_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/riders/requests/9999/reject", headers=auth_headers(token))
    assert response.status_code == 404


def test_get_profile_of_nonexistent_user_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.get("/riders/9999/profile", headers=auth_headers(token))
    assert response.status_code == 404
