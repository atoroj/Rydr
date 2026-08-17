def register_and_login(client, suffix: str) -> tuple[int, str]:
    user = client.post("/users/", json={
        "username": f"badgerider{suffix}", "email": f"badgerider{suffix}@test.com",
        "password": "pass1234", "role": "rider",
    }).json()
    token = client.post("/auth/login", json={
        "email": f"badgerider{suffix}@test.com", "password": "pass1234",
    }).json()["access_token"]
    return user["id"], token


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def create_motorbike(client, user_id: int) -> int:
    return client.post("/motorbikes/", json={
        "user_id": user_id, "type": "Naked", "brand": "Honda", "model": "CB650R", "cc": 650,
    }).json()["id"]


def finish_a_ride(client, rider_id: int, motorbike_id: int) -> None:
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]
    client.patch(f"/rides/{ride_id}/finish")


def badge(data: list, badge_id: str) -> dict:
    return next(b for b in data if b["id"] == badge_id)


# --- Tests ---

def test_badges_endpoint_requires_auth(client):
    response = client.get("/riders/1/badges")
    assert response.status_code == 401


def test_no_badges_achieved_for_a_fresh_rider(client):
    rider_id, token = register_and_login(client, "1")

    response = client.get(f"/riders/{rider_id}/badges", headers=auth_headers(token))

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 8
    assert all(not b["achieved"] for b in data)


def test_first_ride_badge_unlocks_after_one_finished_ride(client):
    rider_id, token = register_and_login(client, "1")
    motorbike_id = create_motorbike(client, rider_id)
    finish_a_ride(client, rider_id, motorbike_id)

    data = client.get(f"/riders/{rider_id}/badges", headers=auth_headers(token)).json()

    assert badge(data, "primera_ruta")["achieved"] is True
    assert badge(data, "diez_rutas")["achieved"] is False
    # Una sola ruta hoy no basta para 2 semanas seguidas.
    assert badge(data, "racha_2")["achieved"] is False


def test_ten_rides_badge_unlocks_after_ten_finished_rides(client):
    rider_id, token = register_and_login(client, "1")
    motorbike_id = create_motorbike(client, rider_id)
    for _ in range(10):
        finish_a_ride(client, rider_id, motorbike_id)

    data = client.get(f"/riders/{rider_id}/badges", headers=auth_headers(token)).json()

    assert badge(data, "diez_rutas")["achieved"] is True
    assert badge(data, "cincuenta_rutas")["achieved"] is False


def test_active_ride_does_not_count_toward_badges(client):
    rider_id, token = register_and_login(client, "1")
    motorbike_id = create_motorbike(client, rider_id)
    client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id})  # sin finalizar

    data = client.get(f"/riders/{rider_id}/badges", headers=auth_headers(token)).json()

    assert badge(data, "primera_ruta")["achieved"] is False


def test_meetup_badges_unlock_after_joining(client):
    organizer_id, organizer_token = register_and_login(client, "org")
    client.post("/meetups", json={
        "title": "Ruta de domingo", "location_lat": 40.4, "location_lng": -3.7,
        "scheduled_at": "2025-06-01T08:00:00",
    }, headers=auth_headers(organizer_token))

    data = client.get(f"/riders/{organizer_id}/badges", headers=auth_headers(organizer_token)).json()

    # El organizador cuenta como participante desde que crea la quedada.
    assert badge(data, "primera_quedada")["achieved"] is True
    assert badge(data, "cinco_quedadas")["achieved"] is False
