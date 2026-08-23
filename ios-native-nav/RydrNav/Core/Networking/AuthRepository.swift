import Foundation

/// Espejo de lib/features/auth/data/auth_repository.dart.
struct AuthRepository {
    private let client = APIClient.shared
    private let keychain = KeychainStore()

    private struct LoginResponse: Decodable { let accessToken: String
        enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
    }

    func login(email: String, password: String) async throws -> UserModel {
        let response: LoginResponse = try await client.request(
            .post, APIConstants.login, body: ["email": email, "password": password])
        keychain.set(response.accessToken, forKey: KeychainStore.Keys.accessToken)

        // El backend no devuelve el usuario en el login, lo buscamos por email.
        let user: UserModel = try await client.request(.get, "\(APIConstants.users)/email/\(email)")
        cache(user)
        return user
    }

    /// `email` viene ya del propio resultado de `GIDSignIn` en el
    /// llamador — el backend no lo manda de vuelta en la respuesta (mismo
    /// motivo que `login`), así que evita un viaje de ida y vuelta de más
    /// para conseguirlo.
    func loginWithGoogle(idToken: String, email: String) async throws -> UserModel {
        let response: LoginResponse = try await client.request(
            .post, APIConstants.googleLogin, body: ["id_token": idToken])
        keychain.set(response.accessToken, forKey: KeychainStore.Keys.accessToken)

        let user: UserModel = try await client.request(.get, "\(APIConstants.users)/email/\(email)")
        cache(user)
        return user
    }

    /// Registro propio (usuario/email/contraseña) — el backend no
    /// devuelve token al crear la cuenta, solo el usuario creado, así
    /// que se encadena con `login` para conseguir la sesión igual que si
    /// hubiera entrado a mano justo después de registrarse.
    func createAccount(username: String, email: String, password: String) async throws -> UserModel {
        // Con barra final: es el path exacto que expone `user_router.py`
        // (`@router.post("/")`), a diferencia del resto de endpoints de
        // esta app — sin ella, FastAPI redirige y el body del POST no
        // siempre sobrevive la redirección.
        let _: UserModel = try await client.request(.post, "\(APIConstants.users)/", body: [
            "username": username, "email": email, "password": password, "role": "rider",
        ])
        return try await login(email: email, password: password)
    }

    /// Pide el código de 6 dígitos por email — el backend responde 204
    /// siempre, exista o no ese email (no filtra qué cuentas están
    /// registradas), así que aquí tampoco hay nada que distinguir.
    func requestPasswordReset(email: String) async throws {
        try await client.requestVoid(.post, APIConstants.forgotPassword, body: ["email": email])
    }

    /// Cambia la contraseña con el código recibido por email. El backend
    /// responde 400 si el código no vale (caducado, incorrecto o ya
    /// usado) — `APIClient` ya lo convierte en un `APIError` que llega
    /// tal cual al llamador.
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        try await client.requestVoid(.post, APIConstants.resetPassword, body: [
            "email": email, "code": code, "new_password": newPassword,
        ])
    }

    func restoreSession() -> UserModel? {
        guard keychain.get(KeychainStore.Keys.accessToken) != nil,
              let idString = keychain.get(KeychainStore.Keys.userId),
              let id = Int(idString),
              let username = keychain.get(KeychainStore.Keys.username),
              let email = keychain.get(KeychainStore.Keys.email)
        else { return nil }
        return UserModel(
            id: id, username: username, email: email,
            avatarUrl: keychain.get(KeychainStore.Keys.avatarUrl),
            isPrivate: keychain.get(KeychainStore.Keys.isPrivate) == "true")
    }

    /// Guarda cambios de perfil (avatar/username/privacidad) vía `/users/me`
    /// y refresca la caché local (Keychain) para que sobrevivan a un
    /// reinicio de la app.
    func updateProfile(username: String? = nil, avatarUrl: String? = nil, isPrivate: Bool? = nil) async throws -> UserModel {
        var body: [String: Any] = [:]
        if let username { body["username"] = username }
        if let avatarUrl { body["avatar_url"] = avatarUrl }
        if let isPrivate { body["is_private"] = isPrivate }

        let user: UserModel = try await client.request(.patch, "\(APIConstants.users)/me", body: body)
        cache(user)
        return user
    }

    private func cache(_ user: UserModel) {
        keychain.set(String(user.id), forKey: KeychainStore.Keys.userId)
        keychain.set(user.username, forKey: KeychainStore.Keys.username)
        keychain.set(user.email, forKey: KeychainStore.Keys.email)
        if let avatarUrl = user.avatarUrl {
            keychain.set(avatarUrl, forKey: KeychainStore.Keys.avatarUrl)
        } else {
            keychain.delete(KeychainStore.Keys.avatarUrl)
        }
        keychain.set(String(user.isPrivate), forKey: KeychainStore.Keys.isPrivate)
    }

    func logout() {
        keychain.deleteAll()
    }
}
