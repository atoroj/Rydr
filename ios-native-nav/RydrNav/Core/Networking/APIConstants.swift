import Foundation

/// Espejo de lib/core/api/api_constants.dart. El simulador de iOS comparte
/// red con el Mac anfitrión, así que `127.0.0.1` funciona directo (a
/// diferencia del emulador Android, que necesita 10.0.2.2).
enum APIConstants {
    static let baseURL = URL(string: "http://127.0.0.1:8000")!

    static let login = "/auth/login"
    static let users = "/users"
    static let motorbikes = "/motorbikes"
    static let rides = "/rides"
    static let routes = "/routes"
    static let riders = "/riders"
    static let meetups = "/meetups"
    static let uploadImage = "/uploads/image"
}
