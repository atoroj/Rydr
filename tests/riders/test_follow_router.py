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


# --- Tests: feed "cerca de ti" ---

MADRID = (40.4168, -3.7038)
BARCELONA = (41.3874, 2.1686)


def create_route(client, author_id: int, lat: float, lng: float, name: str = "Ruta cercana") -> int:
    response = client.post("/routes", json={
        "name": name, "author_id": author_id,
        "geojson": {"type": "LineString", "coordinates": [[lng, lat], [lng + 0.01, lat + 0.01]]},
        "distance_km": 5.0, "duration_minutes": 20,
    })
    assert response.status_code == 201
    return response.json()["id"]


def test_nearby_feed_includes_public_route_within_radius(client):
    viewer_id, viewer_token = register_and_login(client, "1")
    author_id, _ = register_and_login(client, "2")
    create_route(client, author_id, *MADRID)

    response = client.get(
        f"/riders/feed/nearby?lat={MADRID[0]}&lng={MADRID[1]}", headers=auth_headers(viewer_token))

    assert response.status_code == 200
    authors = [item["author"]["id"] for item in response.json()]
    assert author_id in authors


def test_nearby_feed_excludes_route_outside_radius(client):
    _, viewer_token = register_and_login(client, "1")
    author_id, _ = register_and_login(client, "2")
    create_route(client, author_id, *BARCELONA)

    # Desde Madrid, con el radio por defecto (100km) Barcelona (~500km) no entra.
    response = client.get(
        f"/riders/feed/nearby?lat={MADRID[0]}&lng={MADRID[1]}", headers=auth_headers(viewer_token))

    assert response.status_code == 200
    authors = [item["author"]["id"] for item in response.json()]
    assert author_id not in authors


def test_nearby_feed_excludes_private_author(client):
    _, viewer_token = register_and_login(client, "1")
    author_id, author_token = register_and_login(client, "2")
    create_route(client, author_id, *MADRID)
    client.patch("/users/me", json={"is_private": True}, headers=auth_headers(author_token))

    response = client.get(
        f"/riders/feed/nearby?lat={MADRID[0]}&lng={MADRID[1]}", headers=auth_headers(viewer_token))

    assert response.status_code == 200
    authors = [item["author"]["id"] for item in response.json()]
    assert author_id not in authors


def test_nearby_feed_excludes_own_routes(client):
    viewer_id, viewer_token = register_and_login(client, "1")
    create_route(client, viewer_id, *MADRID)

    response = client.get(
        f"/riders/feed/nearby?lat={MADRID[0]}&lng={MADRID[1]}", headers=auth_headers(viewer_token))

    assert response.status_code == 200
    assert response.json() == []
