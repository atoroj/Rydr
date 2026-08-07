"""
Test E2E: Flujo completo de una ruta.

Simula el recorrido real de un rider:
  1. Registro + login
  2. Creación de moto
  3. Inicio de ride
  4. Grabación de track points GPS (ruta por Madrid)
  5. Finalización del ride
  6. Publicación como ruta pública
  7. Verificación de datos y listado de rutas
"""

from datetime import datetime, timedelta, timezone


# ── Coordenadas GPS simuladas (Retiro → Bernabéu, Madrid) ────────────────────

GPS_TRACK = [
    (40.4153, -3.6844, 670.0, 0.0),    # Retiro - inicio
    (40.4168, -3.6890, 672.0, 25.0),
    (40.4195, -3.6950, 675.0, 38.0),
    (40.4220, -3.7010, 673.0, 42.0),
    (40.4260, -3.7060, 668.0, 45.0),
    (40.4295, -3.7100, 665.0, 40.0),
    (40.4335, -3.7130, 660.0, 38.0),
    (40.4370, -3.7155, 658.0, 35.0),
    (40.4395, -3.7185, 655.0, 30.0),
    (40.4418, -3.6884, 660.0, 0.0),    # Bernabéu - fin
]


def _create_user_and_login(client) -> tuple[int, str]:
    """Crea un usuario y devuelve (user_id, access_token)."""
    r = client.post("/users/", json={
        "username": "rider_e2e",
        "email": "e2e@rydr.com",
        "password": "testpass123",
        "role": "rider",
    })
    assert r.status_code == 200, f"Error creando usuario: {r.json()}"
    user_id = r.json()["id"]

    r = client.post("/auth/login", json={
        "email": "e2e@rydr.com",
        "password": "testpass123",
    })
    assert r.status_code == 200, f"Error en login: {r.json()}"
    token = r.json()["access_token"]

    return user_id, token


def _create_motorbike(client, user_id: int) -> int:
    """Crea una moto y devuelve su id."""
    r = client.post("/motorbikes/", json={
        "user_id": user_id,
        "type": "Naked",
        "brand": "Kawasaki",
        "model": "Z900",
        "cc": 900,
        "alias": "La Kawa",
    })
    assert r.status_code == 201, f"Error creando moto: {r.json()}"
    return r.json()["id"]


# ── Tests ────────────────────────────────────────────────────────────────────

def test_flujo_completo_ride_a_ruta(client):
    """Simula el flujo completo: ride con GPS → ruta pública."""
    user_id, _ = _create_user_and_login(client)
    moto_id = _create_motorbike(client, user_id)

    # 1. Iniciar ride
    r = client.post("/rides/", json={"rider_id": user_id, "motorbike_id": moto_id})
    assert r.status_code == 201
    ride = r.json()
    ride_id = ride["id"]
    assert ride["finished_at"] is None
    assert ride["is_public"] is False

    # 2. Añadir track points GPS
    base_time = datetime.now(timezone.utc)
    for i, (lat, lon, alt, speed) in enumerate(GPS_TRACK):
        ts = (base_time + timedelta(seconds=i * 30)).isoformat()
        r = client.post(f"/rides/{ride_id}/track-points", json={
            "latitude": lat,
            "longitude": lon,
            "altitude": alt,
            "speed": speed,
            "timestamp": ts,
        })
        assert r.status_code == 201, f"Error en punto {i}: {r.json()}"

    # 3. Verificar que el ride tiene los puntos
    r = client.get(f"/rides/{ride_id}")
    assert r.status_code == 200
    assert len(r.json()["track_points"]) == len(GPS_TRACK)

    # 4. Finalizar ride
    r = client.patch(f"/rides/{ride_id}/finish")
    assert r.status_code == 200
    finished = r.json()
    assert finished["finished_at"] is not None

    # 5. Publicar como ruta
    r = client.post("/routes/from-ride", json={
        "ride_id": ride_id,
        "name": "Retiro al Bernabéu",
        "description": "Ruta por el centro de Madrid",
    })
    assert r.status_code == 201
    route = r.json()

    assert route["name"] == "Retiro al Bernabéu"
    assert route["distance_km"] > 0
    assert route["duration_minutes"] > 0
    assert route["author_id"] == user_id
    assert route["times_ridden"] == 0
    assert route["geojson"]["type"] == "LineString"
    assert len(route["geojson"]["coordinates"]) == len(GPS_TRACK)

    # 6. La ruta aparece en el listado público
    r = client.get("/routes/")
    assert r.status_code == 200
    ids = [rt["id"] for rt in r.json()]
    assert route["id"] in ids


def test_ride_sin_puntos_no_se_puede_publicar(client):
    """Un ride sin track points no puede convertirse en ruta."""
    user_id, _ = _create_user_and_login(client)
    moto_id = _create_motorbike(client, user_id)

    r = client.post("/rides/", json={"rider_id": user_id, "motorbike_id": moto_id})
    ride_id = r.json()["id"]
    client.patch(f"/rides/{ride_id}/finish")

    r = client.post("/routes/from-ride", json={
        "ride_id": ride_id,
        "name": "Ruta vacía",
    })
    assert r.status_code == 400


def test_ride_activo_no_se_puede_publicar(client):
    """Un ride que no ha terminado no puede convertirse en ruta."""
    user_id, _ = _create_user_and_login(client)
    moto_id = _create_motorbike(client, user_id)

    r = client.post("/rides/", json={"rider_id": user_id, "motorbike_id": moto_id})
    ride_id = r.json()["id"]

    r = client.post("/routes/from-ride", json={
        "ride_id": ride_id,
        "name": "Ruta en curso",
    })
    assert r.status_code == 400


def test_historial_rides_por_rider(client):
    """El rider puede consultar todos sus rides."""
    user_id, _ = _create_user_and_login(client)
    moto_id = _create_motorbike(client, user_id)

    # Crear 3 rides
    for _ in range(3):
        r = client.post("/rides/", json={"rider_id": user_id, "motorbike_id": moto_id})
        ride_id = r.json()["id"]
        client.patch(f"/rides/{ride_id}/finish")

    r = client.get(f"/rides/rider/{user_id}")
    assert r.status_code == 200
    assert len(r.json()) == 3


def test_contador_times_ridden(client):
    """Marcar una ruta como recorrida incrementa su contador."""
    user_id, _ = _create_user_and_login(client)
    moto_id = _create_motorbike(client, user_id)

    # Crear ride con puntos y publicar
    r = client.post("/rides/", json={"rider_id": user_id, "motorbike_id": moto_id})
    ride_id = r.json()["id"]

    base_time = datetime.now(timezone.utc)
    for i, (lat, lon, alt, speed) in enumerate(GPS_TRACK[:3]):
        client.post(f"/rides/{ride_id}/track-points", json={
            "latitude": lat, "longitude": lon,
            "altitude": alt, "speed": speed,
            "timestamp": (base_time + timedelta(seconds=i * 30)).isoformat(),
        })

    client.patch(f"/rides/{ride_id}/finish")
    r = client.post("/routes/from-ride", json={"ride_id": ride_id, "name": "Ruta test"})
    route_id = r.json()["id"]

    # Marcar como recorrida 2 veces
    client.post(f"/routes/{route_id}/ride")
    client.post(f"/routes/{route_id}/ride")

    r = client.get(f"/routes/{route_id}")
    assert r.json()["times_ridden"] == 2
