import CoreLocation
import Foundation

/// Espejo de lib/shared/models/ride_model.dart (TrackPointModel).
struct TrackPointModel: Codable, Equatable {
    let id: Int
    let rideId: Int
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let speed: Double?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, altitude, speed, timestamp
        case rideId = "ride_id"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Espejo de lib/shared/models/ride_model.dart (RideModel).
struct RideModel: Codable, Identifiable, Equatable {
    let id: Int
    let riderId: Int
    let motorbikeId: Int
    let startedAt: Date
    let finishedAt: Date?
    let isPublic: Bool
    let trackPoints: [TrackPointModel]

    enum CodingKeys: String, CodingKey {
        case id, isPublic = "is_public"
        case riderId = "rider_id"
        case motorbikeId = "motorbike_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case trackPoints = "track_points"
    }

    init(
        id: Int, riderId: Int, motorbikeId: Int, startedAt: Date, finishedAt: Date?,
        isPublic: Bool, trackPoints: [TrackPointModel] = []
    ) {
        self.id = id
        self.riderId = riderId
        self.motorbikeId = motorbikeId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.isPublic = isPublic
        self.trackPoints = trackPoints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        riderId = try c.decode(Int.self, forKey: .riderId)
        motorbikeId = try c.decode(Int.self, forKey: .motorbikeId)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        isPublic = try c.decode(Bool.self, forKey: .isPublic)
        trackPoints = try c.decodeIfPresent([TrackPointModel].self, forKey: .trackPoints) ?? []
    }

    var isActive: Bool { finishedAt == nil }
    var path: [CLLocationCoordinate2D] { trackPoints.map(\.coordinate) }
}
