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