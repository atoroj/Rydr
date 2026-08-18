import CoreLocation
import Foundation

/// Espejo de app/meetups/infrastructure/meetup_router.py.
struct MeetupsRepository {
    private let client = APIClient.shared

    // Sin zona horaria, igual que el resto de fechas que manda la app —
    // ver el mismo patrón en RideRepository.
    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    func discover() async throws -> [Meetup] {
        try await client.request(.get, "\(APIConstants.meetups)/discover")
    }

    func mine() async throws -> [Meetup] {
        try await client.request(.get, "\(APIConstants.meetups)/mine")
    }

    func get(id: Int) async throws -> Meetup {
        try await client.request(.get, "\(APIConstants.meetups)/\(id)")
    }

    func create(
        title: String, description: String?, locationName: String?,
        coordinate: CLLocationCoordinate2D, scheduledAt: Date,
        maxParticipants: Int?, isPrivate: Bool,
        locationHidden: Bool = false, approximateArea: String? = nil
    ) async throws -> Meetup {
        try await client.request(.post, APIConstants.meetups, body: body(
            title: title, description: description, locationName: locationName,
            coordinate: coordinate, scheduledAt: scheduledAt,
            maxParticipants: maxParticipants, isPrivate: isPrivate,
            locationHidden: locationHidden, approximateArea: approximateArea))
    }

    func update(
        id: Int, title: String, description: String?, locationName: String?,
        coordinate: CLLocationCoordinate2D, scheduledAt: Date,
        maxParticipants: Int?, isPrivate: Bool,
        locationHidden: Bool = false, approximateArea: String? = nil
    ) async throws -> Meetup {
        try await client.request(.patch, "\(APIConstants.meetups)/\(id)", body: body(
            title: title, description: description, locationName: locationName,
            coordinate: coordinate, scheduledAt: scheduledAt,
            maxParticipants: maxParticipants, isPrivate: isPrivate,
            locationHidden: locationHidden, approximateArea: approximateArea))
    }

    /// Solo el organizador puede llamarlo — ver `MeetupService.reveal_location`.
    /// No hay vuelta atrás: una vez revelada, no se vuelve a ocultar.
    func revealLocation(id: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.meetups)/\(id)/reveal-location")
    }

    func delete(id: Int) async throws {
        try await client.requestVoid(.delete, "\(APIConstants.meetups)/\(id)")
    }

    func join(id: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.meetups)/\(id)/join")
    }

    func leave(id: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.meetups)/\(id)/leave")
    }

    func participants(id: Int) async throws -> [MeetupParticipant] {
        try await client.request(.get, "\(APIConstants.meetups)/\(id)/participants")
    }

    func updateLocation(id: Int, coordinate: CLLocationCoordinate2D) async throws {
        try await client.requestVoid(.post, "\(APIConstants.meetups)/\(id)/location", body: [
            "lat": coordinate.latitude, "lng": coordinate.longitude,
        ])
    }

    func liveLocations(id: Int) async throws -> [MeetupLiveLocation] {
        try await client.request(.get, "\(APIConstants.meetups)/\(id)/live-locations")
    }

    private func body(
        title: String, description: String?, locationName: String?,
        coordinate: CLLocationCoordinate2D, scheduledAt: Date,
        maxParticipants: Int?, isPrivate: Bool,
        locationHidden: Bool, approximateArea: String?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "title": title,
            "location_lat": coordinate.latitude,
            "location_lng": coordinate.longitude,
            "scheduled_at": isoFormatter.string(from: scheduledAt),
            "is_private": isPrivate,
            "location_hidden": locationHidden,
        ]
        if let description, !description.isEmpty { body["description"] = description }
        if let locationName, !locationName.isEmpty { body["location_name"] = locationName }
        if let maxParticipants { body["max_participants"] = maxParticipants }
        if let approximateArea, !approximateArea.isEmpty { body["approximate_area"] = approximateArea }
        return body
    }
}
