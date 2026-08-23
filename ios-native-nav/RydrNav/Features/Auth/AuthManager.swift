import Foundation

extension Notification.Name {
    /// Se dispara cuando cambia la sesión (login/logout), para que la UI
    /// reaccione — equivalente nativo de observar `authProvider` en Riverpod.
    static let authDidChange = Notification.Name("authDidChange")

    /// Se dispara cuando el backend responde 401 a una petición autenticada
    /// (token caducado o inválido) — ver `APIClient.rawRequest`.
    static let sessionExpired = Notification.Name("sessionExpired")
}

/// Estado global de sesión — espejo de `authProvider`/`AuthNotifier`
/// (lib/features/auth/presentation/auth_provider.dart).
final class AuthManager {
    static let shared = AuthManager()

    private let repository = AuthRepository()
    private(set) var currentUser: UserModel?

    private init() {
        currentUser = repository.restoreSession()
        NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.currentUser != nil else { return }
            self.currentUser = nil
            NotificationCenter.default.post(name: .authDidChange, object: nil)
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    func login(email: String, password: String) async throws {
        let user = try await repository.login(email: email, password: password)
        currentUser = user
        NotificationCenter.default.post(name: .authDidChange, object: nil)
    }

    func loginWithGoogle(idToken: String, email: String) async throws {
        let user = try await repository.loginWithGoogle(idToken: idToken, email: email)
        currentUser = user
        NotificationCenter.default.post(name: .authDidChange, object: nil)
    }

    /// Registro propio (usuario/email/contraseña) — deja la sesión ya
    /// iniciada, igual que `login`.
    func createAccount(username: String, email: String, password: String) async throws {
        let user = try await repository.createAccount(username: username, email: email, password: password)
        currentUser = user
        NotificationCenter.default.post(name: .authDidChange, object: nil)
    }

    func logout() {
        repository.logout()
        currentUser = nil
        NotificationCenter.default.post(name: .authDidChange, object: nil)
    }

    /// Restablecer contraseña: ninguno de los dos pasos toca la sesión
    /// (no hay usuario logueado todavía en este flujo), así que solo
    /// reenvían al repositorio.
    func requestPasswordReset(email: String) async throws {
        try await repository.requestPasswordReset(email: email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        try await repository.resetPassword(email: email, code: code, newPassword: newPassword)
    }

    /// Actualiza el perfil (avatar/username/privacidad) y refresca el
    /// estado global para que top bar, ajustes y perfil social se vean al
    /// momento — equivalente a `AuthNotifier.updateProfile` en Flutter.
    func updateProfile(username: String? = nil, avatarUrl: String? = nil, isPrivate: Bool? = nil) async throws {
        let updated = try await repository.updateProfile(username: username, avatarUrl: avatarUrl, isPrivate: isPrivate)
        currentUser = updated
        NotificationCenter.default.post(name: .authDidChange, object: nil)
    }
}
