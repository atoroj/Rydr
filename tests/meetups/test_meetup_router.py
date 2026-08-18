# Primeros tests para `meetups` — no había ninguno todavía. Igual que
# `rides`/`routes`: todo por HTTP contra el `client` fixture, sin mocks.
# A diferencia de esos dos, `meetups` sí está protegido con JWT de verdad,
# así que el helper registra y hace login para tener un token de cada rider.


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


def create_meetup(client, token: str) -> int:
    response = client.post("/meetups", json={
        "title": "Puerto de Pajares al amanecer",
        "location_lat": 42.9942, "location_lng": -5.7597,
        "scheduled_at": "2025-06-01T08:00:00",
    }, headers=auth_headers(token))
    assert response.status_code == 201
    return response.json()["id"]


def create_meetup_with_hidden_location(client, token: str) -> int:
    response = client.post("/meetups", json={
        "title": "Quedada sorpresa del canal",
        "location_lat": 42.9942, "location_lng": -5.7597,
        "scheduled_at": "2025-06-01T08:00:00",
        "location_hidden": True, "approximate_area": "Sierra de Guadarrama",
    }, headers=auth_headers(token))
    assert response.status_code == 201
    return response.json()["id"]


# --- Tests: 404 vs 400 en join/leave sobre una quedada inexistente ---
# (antes devolvían 400 — `_get_or_raise` usaba la misma `ValueError` que
# los errores de validación genuinos, así que el router no podía
# distinguir "no existe" de "la quedada está completa"/"no puedes salir
# de tu propia quedada". Ver `app/shared/errors.py`.)

def test_join_nonexistent_meetup_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/meetups/9999/join", headers=auth_headers(token))
    assert response.status_code == 404


def test_leave_nonexistent_meetup_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/meetups/9999/leave", headers=auth_headers(token))
    assert response.status_code == 404


def test_reveal_location_of_nonexistent_meetup_returns_404(client):
    _, token = register_and_login(client, "1")
    response = client.post("/meetups/9999/reveal-location", headers=auth_headers(token))
    assert response.status_code == 404


# --- Tests: ubicación oculta hasta que el organizador la revele ---

def test_non_joined_viewer_sees_approximate_area_not_exact_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)
    _, outsider_token = register_and_login(client, "2")

    response = client.get(f"/meetups/{meetup_id}", headers=auth_headers(outsider_token))

    assert response.status_code == 200
    data = response.json()
    assert data["location_lat"] is None
    assert data["location_lng"] is None
    assert data["location_name"] is None
    assert data["approximate_area"] == "Sierra de Guadarrama"
    assert data["location_hidden"] is True
    assert data["location_revealed"] is False


def test_joined_but_not_revealed_still_hides_exact_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)
    joiner_id, joiner_token = register_and_login(client, "2")
    client.post(f"/meetups/{meetup_id}/join", headers=auth_headers(joiner_token))

    response = client.get(f"/meetups/{meetup_id}", headers=auth_headers(joiner_token))

    assert response.status_code == 200
    assert response.json()["location_lat"] is None


def test_organizer_always_sees_exact_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)

    response = client.get(f"/meetups/{meetup_id}", headers=auth_headers(organizer_token))

    assert response.status_code == 200
    assert response.json()["location_lat"] == 42.9942


def test_reveal_location_lets_joined_participants_see_exact_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)
    _, joiner_token = register_and_login(client, "2")
    client.post(f"/meetups/{meetup_id}/join", headers=auth_headers(joiner_token))

    reveal_response = client.post(f"/meetups/{meetup_id}/reveal-location", headers=auth_headers(organizer_token))
    assert reveal_response.status_code == 204

    response = client.get(f"/meetups/{meetup_id}", headers=auth_headers(joiner_token))
    assert response.status_code == 200
    data = response.json()
    assert data["location_lat"] == 42.9942
    assert data["location_revealed"] is True


def test_reveal_location_does_not_help_non_joined_viewer(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)
    client.post(f"/meetups/{meetup_id}/reveal-location", headers=auth_headers(organizer_token))
    _, outsider_token = register_and_login(client, "2")

    response = client.get(f"/meetups/{meetup_id}", headers=auth_headers(outsider_token))

    assert response.status_code == 200
    assert response.json()["location_lat"] is None


def test_non_organizer_cannot_reveal_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup_with_hidden_location(client, organizer_token)
    _, outsider_token = register_and_login(client, "2")

    response = client.post(f"/meetups/{meetup_id}/reveal-location", headers=auth_headers(outsider_token))

    assert response.status_code == 403


# --- Tests: ubicación en vivo ---

def test_organizer_can_share_location(client):
    organizer_id, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup(client, organizer_token)

    response = client.post(
        f"/meetups/{meetup_id}/location", json={"lat": 42.99, "lng": -5.76},
        headers=auth_headers(organizer_token),
    )

    assert response.status_code == 204


def test_non_participant_cannot_share_location(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup(client, organizer_token)
    _, outsider_token = register_and_login(client, "2")

    response = client.post(
        f"/meetups/{meetup_id}/location", json={"lat": 42.99, "lng": -5.76},
        headers=auth_headers(outsider_token),
    )

    assert response.status_code == 403


def test_live_locations_shows_participants_who_shared(client):
    organizer_id, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup(client, organizer_token)
    joiner_id, joiner_token = register_and_login(client, "2")
    client.post(f"/meetups/{meetup_id}/join", headers=auth_headers(joiner_token))

    client.post(
        f"/meetups/{meetup_id}/location", json={"lat": 42.99, "lng": -5.76},
        headers=auth_headers(organizer_token),
    )

    response = client.get(f"/meetups/{meetup_id}/live-locations", headers=auth_headers(organizer_token))

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["user_id"] == organizer_id
    assert data[0]["lat"] == 42.99
    assert data[0]["lng"] == -5.76
    # El joiner nunca ha mandado ubicación — no debe salir en la lista.
    assert all(loc["user_id"] != joiner_id for loc in data)


def test_live_locations_empty_when_nobody_shared(client):
    _, organizer_token = register_and_login(client, "1")
    meetup_id = create_meetup(client, organizer_token)

    response = client.get(f"/meetups/{meetup_id}/live-locations", headers=auth_headers(organizer_token))

    assert response.status_code == 200
    assert response.json() == []


def test_live_locations_not_found_for_missing_meetup(client):
    _, token = register_and_login(client, "1")

    response = client.get("/meetups/9999/live-locations", headers=auth_headers(token))

    assert response.status_code == 404
