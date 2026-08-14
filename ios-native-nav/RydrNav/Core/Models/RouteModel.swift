import CoreLocation
import Foundation

/// Espejo de `RouteModel` (lib/shared/models/route_model.dart) — mismo
/// backend, mismo JSON, sin tocar nada del lado Flutter.
struct RouteModel: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let description: String?
    let authorId: Int
    let geojson: GeoJSONLineString
    let distanceKm: Double
    let durationMinutes: Int
    let timesRidden: Int
    let coverImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case authorId = "author_id"
        case geojson
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case timesRidden = "times_ridden"
        case coverImageUrl = "cover_image_url"
    }

    /// Puntos exactos grabados por el motero, en orden.
    var path: [CLLocationCoordinate2D] {
        geojson.coordinates.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}

struct GeoJSONLineString: Codable, Equatable {
    let coordinates: [[Double]]
}
