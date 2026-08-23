import Foundation

/// Espejo de lib/core/api/api_constants.dart. El simulador de iOS comparte
/// red con el Mac anfitrión, así que `127.0.0.1` funciona directo (a
/// diferencia del emulador Android, que necesita 10.0.2.2) — pero un
/// iPhone físico es un dispositivo de red aparte: ahí `127.0.0.1` apunta
/// al propio teléfono, nunca al Mac. Hace falta la IP del Mac en la red
/// local (los dos en el mismo Wi-Fi) y arrancar el backend escuchando en
/// todas las interfaces, no solo loopback (`pipenv run dev` ya lo hace
/// con `--host 0.0.0.0`, ver Pipfile).
enum APIConstants {
    #if targetEnvironment(simulator)
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    // Actualiza esta IP si cambias de red — es la que tenía el Mac al
    // escribir esto (`ipconfig getifaddr en0`).
    static let baseURL = URL(string: "http://192.168.0.5:8000")!
    #endif

    static let login = "/auth/login"
    static let googleLogin = "/auth/google"
    static let forgotPassword = "/auth/forgot-password"
    static let resetPassword = "/auth/reset-password"
    static let users = "/users"
    static let motorbikes = "/motorbikes"
    static let rides = "/rides"
    static let routes = "/routes"
    static let riders = "/riders"
    static let meetups = "/meetups"
    static let uploadImage = "/uploads/image"

    // Términos/privacidad (ver ./legal en la raíz del repo) — los sirve
    // Caddy directamente, no el backend (ver DEPLOY.md), así que viven en
    // un host aparte de `baseURL` en desarrollo (donde el backend corre
    // suelto con `pipenv run dev`, sin Caddy delante). Para probarlos en
    // local hace falta el `docker compose up` de la raíz del repo
    // corriendo a la vez. Actualiza esto al dominio real en cuanto haya
    // un servidor de verdad desplegado (ver DEPLOY.md).
    #if targetEnvironment(simulator)
    static let legalBaseURL = URL(string: "https://127.0.0.1")!
    #else
    static let legalBaseURL = URL(string: "https://192.168.0.5")!
    #endif
    static let termsURL = legalBaseURL.appendingPathComponent("legal/terms.html")
    static let privacyURL = legalBaseURL.appendingPathComponent("legal/privacy.html")
}
