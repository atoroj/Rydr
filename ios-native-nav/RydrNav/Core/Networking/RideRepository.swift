import Foundation

/// Espejo de lib/features/rides/data/ride_repository.dart.
struct RideRepository {
    private let client = APIClient.shared

    // Sin zona horaria, igual que las fechas "naive" que el backend nos
    // devuelve — mandar un formato con "Z" aquí sería inconsistente con lo
    // que él mismo produce y espera.
    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()

    func startRide(riderId: Int, motorbikeId: Int) async throws -> RideModel {
        try await client.request(
            .post, APIConstants.rides,
            body: ["rider_id": riderId, "motorbike_id": motorbikeId])
    }

    func finishRide(rideId: Int) async throws -> RideModel {
        try await client.request(.patch, "\(APIConstants.rides)/\(rideId)/finish")
    }

    func addTrackPoint(
        rideId: Int, latitude: Double, longitude: Double,
        altitude: Double?, speed: Double?, timestamp: Date
    ) async throws {
        var body: [String: Any] = [
            "latitude": latitude, "longitude": longitude,
            "timestamp": isoFormatter.string(from: timestamp),
        ]
        if let altitude { body["altitude"] = altitude }
        if let speed { body["speed"] = speed }
        try await client.requestVoid(.post, "\(APIConstants.rides)/\(rideId)/track-points", body: body)
    }

    /// Reenvía de golpe los puntos que se quedaron en cola local por falta
    /// de cobertura — ver `RideTrackSyncManager`. `[String: Any]` porque
    /// cada elemento ya viene formado (mismas claves que `addTrackPoint`)
    /// desde la propia cola, sin pasar por un `Codable` intermedio.
    func addTrackPointsBatch(rideId: Int, points: [[String: Any]]) async throws {
        guard !points.isEmpty else { return }
        try await client.requestVoid(
            .post, "\(APIConstants.rides)/\(rideId)/track-points/batch", body: ["points": points])
    }

    func getRides(riderId: Int) async throws -> [RideModel] {
        try await client.request(.get, "\(APIConstants.rides)/rider/\(riderId)")
    }

    func getRide(id: Int) async throws -> RideModel {
        try await client.request(.get, "\(APIConstants.rides)/\(id)")
    }

    /// Borra un ride del backend por completo (no lo marca como descartado,
    /// lo elimina). Se usa para rides demasiado cortos como para conservar.
    func deleteRide(id: Int) async throws {
        try await client.requestVoid(.delete, "\(APIConstants.rides)/\(id)")
    }
}
