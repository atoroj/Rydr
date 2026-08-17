import Foundation

/// Espejo de lib/features/routes/data/route_repository.dart. Ojo: esto llama
/// a TU backend (guardar/leer rutas), no tiene nada que ver con
/// `MapMatchingService`, que llama a la API de Mapbox para sacar los giros.
struct RouteRepository {
    private let client = APIClient.shared

    func getPublicRoutes() async throws -> [RouteModel] {
        try await client.request(.get, APIConstants.routes)
    }

    func getRoutes(userId: Int) async throws -> [RouteModel] {
        try await client.request(.get, "\(APIConstants.routes)/user/\(userId)")
    }

    func getRoute(id: Int) async throws -> RouteModel {
        try await client.request(.get, "\(APIConstants.routes)/\(id)")
    }

    func createRoute(
        fromRide rideId: Int, name: String, description: String?, coverImageUrl: String? = nil
    ) async throws -> RouteModel {
        var body: [String: Any] = ["ride_id": rideId, "name": name]
        if let description { body["description"] = description }
        if let coverImageUrl { body["cover_image_url"] = coverImageUrl }
        return try await client.request(.post, "\(APIConstants.routes)/from-ride", body: body)
    }

    /// A diferencia de `createRoute(fromRide:...)` (que hace que el backend
    /// derive el trazado de `ride.track_points`), aquí el geojson/distancia/
    /// duración se mandan ya calculados desde el propio móvil — para
    /// publicar justo al terminar de grabar sin depender de que la cola de
    /// `RideTrackSyncManager` haya terminado de llegar al backend todavía
    /// (`trackCoordinates`, en memoria, siempre está completo).
    func createRoute(
        name: String, description: String?, authorId: Int, geojson: [String: Any],
        distanceKm: Double, durationMinutes: Int, coverImageUrl: String? = nil
    ) async throws -> RouteModel {
        var body: [String: Any] = [
            "name": name, "author_id": authorId, "geojson": geojson,
            "distance_km": distanceKm, "duration_minutes": durationMinutes,
        ]
        if let description { body["description"] = description }
        if let coverImageUrl { body["cover_image_url"] = coverImageUrl }
        return try await client.request(.post, APIConstants.routes, body: body)
    }

    func markAsRidden(routeId: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.routes)/\(routeId)/ride")
    }
}
