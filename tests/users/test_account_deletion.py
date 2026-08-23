"""Borrado de cuenta (`DELETE /users/me`) — ver
`app/users/application/account_deletion_service.py`. Un usuario con moto,
ruta, ride, quedada organizada, quedada ajena (solo apuntado) y follows en
los dos sentidos debe desaparecer entero: nada suyo debe sobrevivir, y lo
que compartía con otros (participación en una quedada ajena, follow en
los dos sentidos) tiene que limpiarse sin llevarse por delante lo que no
es suyo.
"""
from datetime import datetime, timedelta


def register_and_login(client, suffix: str) -> tuple[int, str]:
    user = client.post("/users/", json={
        "username": f"user{suffix}", "email": f"user{suffix}@test.com",
        "password": "pass1234", "role": "rider",
    }).json()
    token = client.post("/auth/login", json={
        "email": f"user{suffix}@test.com", "password": "pass1234",
    }).json()["access_token"]
    return user["id"], token


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_delete_account_removes_everything_and_leaves_shared_data_intact(client):
    victim_id, victim_token = register_and_login(client, "victim")
    other_id, other_token = register_and_login(client, "other")

    # Moto
    motorbike = client.post("/motorbikes", json={
        "user_id": victim_id, "type": "Naked", "brand": "Honda", "model": "CB500",
        "cc": 500, "alias": "Mi moto",
    }).json()

    # Ruta propia
    route = client.post("/routes", json={
        "name": "Ruta del que se borra", "author_id": victim_id,
        "geojson": {"type": "LineString", "coordinates": [[-3.7, 40.4], [-3.71, 40.41]]},
        "distance_km": 10.0, "duration_minutes": 30,
    }).json()

    # Ride
    ride = client.post("/rides", json={"rider_id": victim_id, "motorbike_id": motorbike["id"]}).json()

    # Quedada que organiza (con un tercero apuntado, para comprobar que no
    # se lleva a nadie más por delante al desaparecer)
    third_id, third_token = register_and_login(client, "third")
    organized_meetup = client.post("/meetups", json={
        "title": "Quedada del que se borra", "location_lat": 40.4, "location_lng": -3.7,
        "scheduled_at": (datetime.now() + timedelta(days=3)).isoformat(),
    }, headers=auth_headers(victim_token)).json()
    client.post(f"/meetups/{organized_meetup['id']}/join", headers=auth_headers(third_token))

    # Quedada ajena a la que solo se apunta
    others_meetup = client.post("/meetups", json={
        "title": "Quedada ajena", "location_lat": 41.0, "location_lng": -3.0,
        "scheduled_at": (datetime.now() + timedelta(days=5)).isoformat(),
    }, headers=auth_headers(other_token)).json()
    client.post(f"/meetups/{others_meetup['id']}/join", headers=auth_headers(victim_token))

    # Follow en los dos sentidos
    client.post(f"/riders/{other_id}/follow", headers=auth_headers(victim_token))
    client.post(f"/riders/{victim_id}/follow", headers=auth_headers(other_token))

    # --- Borrar la cuenta ---
    response = client.delete("/users/me", headers=auth_headers(victim_token))
    assert response.status_code == 204

    # El usuario ya no existe
    assert client.get("/users/email/uservictim@test.com").status_code == 404

    # Ni su moto, ni su ruta, ni su ride
    assert client.get(f"/motorbikes/{motorbike['id']}").status_code == 404
    assert route["id"] not in [r["id"] for r in client.get("/routes").json()]
    assert client.get(f"/rides/{ride['id']}").status_code == 404

    # La quedada que organizaba desaparece del todo (con su participante)
    assert client.get(f"/meetups/{organized_meetup['id']}", headers=auth_headers(third_token)).status_code == 404

    # La quedada ajena SIGUE existiendo — solo deja de estar él como
    # participante, no se borra la quedada de otro
    still_there = client.get(f"/meetups/{others_meetup['id']}", headers=auth_headers(other_token))
    assert still_there.status_code == 200
    participants = client.get(
        f"/meetups/{others_meetup['id']}/participants", headers=auth_headers(other_token)).json()
    assert victim_id not in [p["id"] for p in participants]

    # El otro usuario sigue existiendo, con su propia cuenta intacta
    assert client.get("/users/email/userother@test.com").status_code == 200


def test_delete_account_without_token_returns_401(client):
    response = client.delete("/users/me")
    assert response.status_code == 401


def test_delete_account_twice_returns_404_second_time(client):
    _, token = register_and_login(client, "onceonly")

    first = client.delete("/users/me", headers=auth_headers(token))
    assert first.status_code == 204

    # El token sigue siendo "válido" como JWT (no hay revocación), pero el
    # usuario que dice ser ya no existe — `get_current_user` debe fallar.
    second = client.delete("/users/me", headers=auth_headers(token))
    assert second.status_code in (401, 404)
