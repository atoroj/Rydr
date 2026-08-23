import CoreLocation
import Foundation

/// Espejo de app/riders/application/follow_dto.py — mismo backend, mismo JSON.

struct MotorbikeSummary: Codable, Equatable {
    let id: Int
    let brand: String
    let model: String
    let alias: String?
    let photoUrl: String?
    let year: Int?

    enum CodingKeys: String, CodingKey {
        case id, brand, model, alias, year
        case photoUrl = "photo_url"
    }

    var displayName: String { alias ?? "\(brand) \(model)" }
}

struct RouteSummary: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let geojson: GeoJSONLineString
    let distanceKm: Double
    let durationMinutes: Int
    let coverImageUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, geojson
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case coverImageUrl = "cover_image_url"
        case createdAt = "created_at"
    }

    var path: [CLLocationCoordinate2D] {
        geojson.segments.flatMap { $0.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } }
    }

    /// Ver `RouteModel.segments` — cada tramo por separado, para no dibujar
    /// el hueco de una pausa como si fuera carretera recorrida.
    var segments: [[CLLocationCoordinate2D]] {
        geojson.segments.map { $0.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } }
    }
}

/// `followStatus`: "self" | "not_following" | "pending" | "following".
struct RiderSummary: Codable, Equatable, Identifiable {
    let id: Int
    let username: String
    let avatarUrl: String?
    let isPrivate: Bool
    let followStatus: String
    let currentMotorbike: MotorbikeSummary?

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
        case isPrivate = "is_private"
        case followStatus = "follow_status"
        case currentMotorbike = "current_motorbike"
    }
}

struct FollowRequest: Codable, Equatable, Identifiable {
    let id: Int // id de la solicitud (follow.id) — se usa para aceptar/rechazar
    let fromUser: RiderSummary
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUser = "from_user"
        case createdAt = "created_at"
    }
}

/// Un elemento del feed de portada: una ruta publicada por alguien a quien
/// sigues. Espejo de `FeedItemResponse` (app/riders/application/follow_dto.py).
struct FeedItem: Codable, Equatable, Identifiable {
    let author: RiderSummary
    let route: RouteSummary

    var id: Int { route.id }
}

struct RiderProfile: Codable, Equatable {
    let id: Int
    let username: String
    let avatarUrl: String?
    let isPrivate: Bool
    let followStatus: String
    let isVisible: Bool
    let currentMotorbike: MotorbikeSummary?
    let recentRoutes: [RouteSummary]

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
        case isPrivate = "is_private"
        case followStatus = "follow_status"
        case isVisible = "is_visible"
        case currentMotorbike = "current_motorbike"
        case recentRoutes = "recent_routes"
    }
}
