def test_login_successful(client):
    # 1. SETUP: Primero necesitamos crear un usuario real en la BD de prueba
    user_data = {"username": "tester", "email": "test@example.com", "password": "securepassword123", "role": "rider"}
    response_create = client.post("/users/", json=user_data)
    assert response_create.status_code == 200

    login_data = {"email": "test@example.com", "password": "securepassword123"}
    response = client.post("/auth/login", json=login_data)
    
    if response.status_code != 200:
        print("\nERROR DETALLE:", response.json())
    
    # 3. ASSERT: Verificamos que devuelve el token
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_login_wrong_password(client):
    # 1. SETUP: Crear usuario
    user_data = {"username": "tester", "email": "test@example.com", "password": "securepassword123", "role": "rider"}
    client.post("/users/", json=user_data)

    # 2. ACT: Login con contraseña mal
    login_data = {
        "email": "test@example.com",
        "password": "WRONG_PASSWORD"
    }
    response = client.post("/auth/login", json=login_data)

    # 3. ASSERT: Debe fallar
    assert response.status_code == 401


# --- Tests: login con Google ---
# No se puede generar un ID token firmado de verdad por Google en un
# test, así que se monkeypatchea `verify_google_id_token` justo donde
# `auth_service.py` lo importa — ver `app/auth/infrastructure/google_verifier.py`.

def _mock_google_account(monkeypatch, **overrides):
    from app.auth.infrastructure.google_verifier import GoogleAccount

    account = GoogleAccount(
        email=overrides.get("email", "nuevo@gmail.com"),
        name=overrides.get("name", "Nuevo Rider"),
        google_id=overrides.get("google_id", "google-uid-123"),
        avatar_url=overrides.get("avatar_url", "https://example.com/foto.jpg"),
    )
    monkeypatch.setattr("app.auth.application.auth_service.verify_google_id_token", lambda id_token: account)
    return account


def test_login_with_google_creates_new_user(client, monkeypatch):
    _mock_google_account(monkeypatch, email="nuevo@gmail.com", avatar_url="https://example.com/foto.jpg")

    response = client.post("/auth/google", json={"id_token": "fake-token"})

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

    user = client.get("/users/email/nuevo@gmail.com").json()
    assert user["email"] == "nuevo@gmail.com"
    assert user["avatar_url"] == "https://example.com/foto.jpg"


def test_login_with_google_links_existing_password_account_without_duplicating(client, monkeypatch):
    client.post("/users/", json={
        "username": "yaexistia", "email": "yaexistia@gmail.com", "password": "pass1234", "role": "rider",
    })
    _mock_google_account(monkeypatch, email="yaexistia@gmail.com")

    response = client.post("/auth/google", json={"id_token": "fake-token"})

    assert response.status_code == 200
    all_users = client.get("/users/").json()
    matching = [u for u in all_users if u["email"] == "yaexistia@gmail.com"]
    assert len(matching) == 1


def test_login_with_google_invalid_token_returns_401(client, monkeypatch):
    from app.auth.infrastructure.google_verifier import InvalidGoogleTokenError

    def raise_invalid(id_token):
        raise InvalidGoogleTokenError("token expirado")

    monkeypatch.setattr("app.auth.application.auth_service.verify_google_id_token", raise_invalid)

    response = client.post("/auth/google", json={"id_token": "fake-token"})

    assert response.status_code == 401


def test_password_login_on_google_only_account_returns_401_not_500(client, monkeypatch):
    # Cuenta creada solo por Google — sin contraseña propia.
    _mock_google_account(monkeypatch, email="sologoogle@gmail.com")
    client.post("/auth/google", json={"id_token": "fake-token"})

    response = client.post("/auth/login", json={"email": "sologoogle@gmail.com", "password": "cualquiera"})

    assert response.status_code == 401

# --- Tests: restablecer contraseña ---

def test_forgot_password_nonexistent_email_still_returns_204_and_sends_nothing(client, monkeypatch):
    sent = []
    monkeypatch.setattr("app.auth.application.auth_service.send_email", lambda **kwargs: sent.append(kwargs))

    response = client.post("/auth/forgot-password", json={"email": "no-existe@example.com"})

    assert response.status_code == 204
    assert sent == []


def _request_reset_code(client, monkeypatch, email: str) -> str:
    captured = {}

    def fake_send_email(to, subject, html):
        captured["html"] = html

    monkeypatch.setattr("app.auth.application.auth_service.send_email", fake_send_email)
    response = client.post("/auth/forgot-password", json={"email": email})
    assert response.status_code == 204

    import re
    match = re.search(r">(\d{6})<", captured["html"])
    assert match, "no se encontró el código de 6 dígitos en el email"
    return match.group(1)


def test_reset_password_with_correct_code_changes_password(client, monkeypatch):
    client.post("/users/", json={
        "username": "resetuser", "email": "reset@example.com", "password": "oldpassword1", "role": "rider",
    })
    code = _request_reset_code(client, monkeypatch, "reset@example.com")

    response = client.post("/auth/reset-password", json={
        "email": "reset@example.com", "code": code, "new_password": "newpassword2",
    })
    assert response.status_code == 200

    old_login = client.post("/auth/login", json={"email": "reset@example.com", "password": "oldpassword1"})
    assert old_login.status_code == 401

    new_login = client.post("/auth/login", json={"email": "reset@example.com", "password": "newpassword2"})
    assert new_login.status_code == 200


def test_reset_password_with_wrong_code_returns_400(client, monkeypatch):
    client.post("/users/", json={
        "username": "resetuser2", "email": "reset2@example.com", "password": "oldpassword1", "role": "rider",
    })
    _request_reset_code(client, monkeypatch, "reset2@example.com")

    response = client.post("/auth/reset-password", json={
        "email": "reset2@example.com", "code": "000000", "new_password": "newpassword2",
    })
    assert response.status_code == 400

    still_old = client.post("/auth/login", json={"email": "reset2@example.com", "password": "oldpassword1"})
    assert still_old.status_code == 200


def test_reset_password_code_can_only_be_used_once(client, monkeypatch):
    client.post("/users/", json={
        "username": "resetuser3", "email": "reset3@example.com", "password": "oldpassword1", "role": "rider",
    })
    code = _request_reset_code(client, monkeypatch, "reset3@example.com")

    first = client.post("/auth/reset-password", json={
        "email": "reset3@example.com", "code": code, "new_password": "newpassword2",
    })
    assert first.status_code == 200

    second = client.post("/auth/reset-password", json={
        "email": "reset3@example.com", "code": code, "new_password": "anotherpassword3",
    })
    assert second.status_code == 400


def test_reset_password_without_requesting_returns_400(client):
    client.post("/users/", json={
        "username": "resetuser4", "email": "reset4@example.com", "password": "oldpassword1", "role": "rider",
    })

    response = client.post("/auth/reset-password", json={
        "email": "reset4@example.com", "code": "123456", "new_password": "newpassword2",
    })
    assert response.status_code == 400
