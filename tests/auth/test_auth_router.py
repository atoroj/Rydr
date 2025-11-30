def test_login_successful(client):
    # 1. SETUP: Primero necesitamos crear un usuario real en la BD de prueba
    user_data = {"username": "tester", "email": "test@example.com", "password": "securepassword123"}
    response_create = client.post("/users/", json=user_data)
    
    if response_create.status_code != 200:
        print("\nERROR AL CREAR USUARIO:", response_create.json())
        
    assert response_create.status_code == 200

    # 2. ACT: Intentamos loguearnos con ese usuario
    # OJO: OAuth2 usa 'username' y 'password' como campos de formulario.
    # Endpoint espera 'username' aunque tú lo trates como email internamente en el service.
    login_data = {
        "email": "test@example.com",  # En tu form_data esto mapea al email
        "password": "securepassword123"
    }
    
    # Usamos data=... (Form Data), NO json=...
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
    user_data = {"username": "tester", "email": "test@example.com", "password": "securepassword123"}
    client.post("/users/", json=user_data)

    # 2. ACT: Login con contraseña mal
    login_data = {
        "email": "test@example.com",
        "password": "WRONG_PASSWORD"
    }
    response = client.post("/auth/login", json=login_data)

    # 3. ASSERT: Debe fallar
    assert response.status_code == 401