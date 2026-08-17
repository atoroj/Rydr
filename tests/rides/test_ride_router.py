from datetime import datetime


# --- Helpers ---

def create_user_and_motorbike(client) -> tuple[int, int]:
    user = client.post("/users/", json={
        "username": "rider1", "email": "rider1@test.com", "password": "pass1234", "role": "user"
    }).json()
    motorbike = client.post("/motorbikes/", json={
        "user_id": user["id"], "type": "Naked", "brand": "Honda", "model": "CB650R", "cc": 650
    }).json()
    return user["id"], motorbike["id"]


# --- Tests: start ride ---

def test_start_ride(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)

    response = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id})

    assert response.status_code == 201
    data = response.json()
    assert data["rider_id"] == rider_id
    assert data["motorbike_id"] == motorbike_id
    assert data["finished_at"] is None
    assert data["is_public"] is False
    assert data["track_points"] == []


def test_start_multiple_rides_same_rider(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)

    client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id})
    client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id})

    response = client.get(f"/rides/rider/{rider_id}")
    assert response.status_code == 200
    assert len(response.json()) == 2


# --- Tests: track points ---

def test_add_track_point(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    response = client.post(f"/rides/{ride_id}/track-points", json={
        "latitude": 40.4168,
        "longitude": -3.7038,
        "altitude": 655.0,
        "speed": 45.2,
        "timestamp": "2025-06-01T10:00:00",
    })

    assert response.status_code == 201
    data = response.json()
    assert data["ride_id"] == ride_id
    assert data["latitude"] == 40.4168
    assert data["longitude"] == -3.7038
    assert data["speed"] == 45.2


# --- Tests: track points en lote (reenvío tras recuperar cobertura) ---

def test_add_track_points_batch(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    response = client.post(f"/rides/{ride_id}/track-points/batch", json={"points": [
        {"latitude": 40.40, "longitude": -3.70, "timestamp": "2025-06-01T10:00:00"},
        {"latitude": 40.41, "longitude": -3.71, "altitude": 650.0, "speed": 52.3, "timestamp": "2025-06-01T10:00:05"},
        {"latitude": 40.42, "longitude": -3.72, "timestamp": "2025-06-01T10:00:10"},
    ]})

    assert response.status_code == 201
    assert response.json() == {"created": 3}

    ride = client.get(f"/rides/{ride_id}").json()
    assert len(ride["track_points"]) == 3
    assert ride["track_points"][1]["speed"] == 52.3


def test_add_track_points_batch_empty(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    response = client.post(f"/rides/{ride_id}/track-points/batch", json={"points": []})

    assert response.status_code == 201
    assert response.json() == {"created": 0}


def test_get_ride_includes_track_points(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    client.post(f"/rides/{ride_id}/track-points", json={
        "latitude": 40.4168, "longitude": -3.7038, "timestamp": "2025-06-01T10:00:00",
    })
    client.post(f"/rides/{ride_id}/track-points", json={
        "latitude": 40.4200, "longitude": -3.7100, "timestamp": "2025-06-01T10:01:00",
    })

    response = client.get(f"/rides/{ride_id}")
    assert response.status_code == 200
    assert len(response.json()["track_points"]) == 2


# --- Tests: finish ride ---

def test_finish_ride(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    response = client.patch(f"/rides/{ride_id}/finish")

    assert response.status_code == 200
    data = response.json()
    assert data["finished_at"] is not None


def test_finish_ride_not_found(client):
    response = client.patch("/rides/9999/finish")
    assert response.status_code == 404


# --- Tests: get ride ---

def test_get_ride_not_found(client):
    response = client.get("/rides/9999")
    assert response.status_code == 404


def test_get_rides_by_rider_empty(client):
    response = client.get("/rides/rider/9999")
    assert response.status_code == 200
    assert response.json() == []
