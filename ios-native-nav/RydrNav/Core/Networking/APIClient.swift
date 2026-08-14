import Foundation

struct APIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Cliente HTTP mínimo — equivalente nativo de `ApiClient` (lib/core/api),
/// que en Flutter usa Dio con un interceptor que añade el JWT. Aquí leemos
/// el token del Keychain en cada petición y limpiamos la sesión si el
/// backend responde 401 (token caducado/inválido), igual que el interceptor
/// original.
final class APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let keychain = KeychainStore()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // El backend manda fechas "naive" — sin zona horaria, tal cual las
        // produce `datetime.utcnow().isoformat()` en Python — y con un
        // número variable de dígitos de microsegundos (o ninguno si la
        // fracción es cero: "2026-08-12T12:27:03" vs
        // "2026-08-12T12:27:03.596690"). `ISO8601DateFormatter` exige zona
        // horaria y por eso fallaba siempre. Las tratamos como UTC, que es
        // lo que representan de verdad.
        let baseFormatter = DateFormatter()
        baseFormatter.calendar = Calendar(identifier: .iso8601)
        baseFormatter.locale = Locale(identifier: "en_US_POSIX")
        baseFormatter.timeZone = TimeZone(identifier: "UTC")
        baseFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let parts = string.split(separator: ".", maxSplits: 1)
            guard let baseDate = baseFormatter.date(from: String(parts[0])) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Fecha no reconocida: \(string)")
            }
            if parts.count == 2, let fraction = Double("0.\(parts[1])") {
                return baseDate.addingTimeInterval(fraction)
            }
            return baseDate
        }
        return d
    }()

    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    /// Petición que decodifica una respuesta JSON al tipo `T`.
    func request<T: Decodable>(_ method: Method, _ path: String, body: [String: Any]? = nil) async throws -> T {
        let data = try await rawRequest(method, path, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(message: "No se pudo interpretar la respuesta del servidor: \(error)")
        }
    }

    /// Petición cuyo cuerpo de respuesta no nos interesa (solo importa que
    /// no falle), como marcar una ruta como recorrida.
    func requestVoid(_ method: Method, _ path: String, body: [String: Any]? = nil) async throws {
        _ = try await rawRequest(method, path, body: body)
    }

    private func rawRequest(_ method: Method, _ path: String, body: [String: Any]?) async throws -> Data {
        guard let url = URL(string: APIConstants.baseURL.absoluteString + path) else {
            throw APIError(message: "URL inválida: \(path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = keychain.get(KeychainStore.Keys.accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Respuesta inválida del servidor")
        }

        if http.statusCode == 401 {
            // Token caducado/inválido: lo borramos y avisamos a AuthManager
            // para que vuelva a la pantalla de login en vez de dejar la app
            // "logueada" en apariencia pero fallando en silencio en cada
            // petición autenticada (Riders es lo primero que valida el JWT
            // de verdad en el backend, así que es donde más se nota).
            keychain.delete(KeychainStore.Keys.accessToken)
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIError(message: "Error del servidor (\(http.statusCode))")
        }
        return data
    }
}
