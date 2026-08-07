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


def create_finished_ride_with_track_points(client, rider_id: int, motorbike_id: int) -> int:
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]
    for lat, lon in [(40.4168, -3.7038), (40.4200, -3.7100), (40.4250, -3.7150)]:
        client.post(f"/rides/{ride_id}/track-points", json={
            "latitude": lat, "longitude": lon, "timestamp": "2025-06-01T10:00:00",
        })
    client.patch(f"/rides/{ride_id}/finish")
    return ride_id


MANUAL_ROUTE_PAYLOAD = {
    "name": "Ruta de prueba",
    "description": "Por la sierra",
    "author_id": 1,
    "geojson": {"type": "LineString", "coordinates": [[-3.7038, 40.4168], [-3.7100, 40.4200]]},
    "distance_km": 5.2,
    "duration_minutes": 30,
}


# --- Tests: create route manually ---

def test_create_route_manually(client):
    rider_id, _ = create_user_and_motorbike(client)
    payload = {**MANUAL_ROUTE_PAYLOAD, "author_id": rider_id}

    response = client.post("/routes/", json=payload)

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Ruta de prueba"
    assert data["distance_km"] == 5.2
    assert data["times_ridden"] == 0
    assert data["geojson"]["type"] == "LineString"


# --- Tests: create route from ride ---

def test_create_route_from_finished_ride(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = create_finished_ride_with_track_points(client, rider_id, motorbike_id)

    response = client.post("/routes/from-ride", json={
        "ride_id": ride_id,
        "name": "Ruta generada desde ride",
        "description": "Generada automáticamente",
    })

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Ruta generada desde ride"
    assert data["author_id"] == rider_id
    assert data["geojson"]["type"] == "LineString"
    assert len(data["geojson"]["coordinates"]) == 3
    assert data["distance_km"] > 0


def test_create_route_from_unfinished_ride_returns_400(client):
    rider_id, motorbike_id = create_user_and_motorbike(client)
    ride_id = client.post("/rides/", json={"rider_id": rider_id, "motorbike_id": motorbike_id}).json()["id"]

    response = client.post("/routes/from-ride", json={"ride_id": ride_id, "name": "Ruta fallida"})

    assert response.status_code == 400


def test_create_route_from_nonexistent_ride_returns_404(client):
    response = client.post("/routes/from-ride", json={"ride_id": 9999, "name": "No existe"})
    assert response.status_code == 404


# --- Tests: list and get routes ---

def test_list_routes_empty(client):
    response = client.get("/routes/")
    assert response.status_code == 200
    assert response.json() == []


def test_list_routes_returns_all(client):
    rider_id, _ = create_user_and_motorbike(client)
    payload = {**MANUAL_ROUTE_PAYLOAD, "author_id": rider_id}
    client.post("/routes/", json=payload)
    client.post("/routes/", json={**payload, "name": "Segunda ruta"})

    response = client.get("/routes/")
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_get_route_by_id(client):
    rider_id, _ = create_user_and_motorbike(client)
    route_id = client.post("/routes/", json={**MANUAL_ROUTE_PAYLOAD, "author_id": rider_id}).json()["id"]

    response = client.get(f"/routes/{route_id}")
    assert response.status_code == 200
    assert response.json()["id"] == route_id


def test_get_route_not_found(client):
    response = client.get("/routes/9999")
    assert response.status_code == 404


# --- Tests: ride route (incrementar contador) ---

def test_ride_route_increments_times_ridden(client):
    rider_id, _ = create_user_and_motorbike(client)
    route_id = client.post("/routes/", json={**MANUAL_ROUTE_PAYLOAD, "author_id": rider_id}).json()["id"]

    client.post(f"/routes/{route_id}/ride")
    client.post(f"/routes/{route_id}/ride")

    response = client.get(f"/routes/{route_id}")
    assert response.json()["times_ridden"] == 2


def test_ride_nonexistent_route_returns_404(client):
    response = client.post("/routes/9999/ride")
    assert response.status_code == 404
