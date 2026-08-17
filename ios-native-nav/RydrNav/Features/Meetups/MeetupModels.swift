import CoreLocation
import Foundation

/// Espejo de app/meetups/application/meetup_dto.py.

struct MeetupOrganizer: Codable, Equatable {
    let id: Int
    let username: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
    }
}

/// Quedada para organizar una ruta en grupo. Privada = solo visible/
/// apuntable para quien sigue al organizador ("para amigos"); pública =
/// cualquiera puede verla y apuntarse.
struct Meetup: Codable, Equatable, Identifiable {
    let id: Int
    let organizer: MeetupOrganizer
    let title: String
    let description: String?
    let locationName: String?
    let locationLat: Double
    let locationLng: Double
    let scheduledAt: Date
    let maxParticipants: Int?
    let participantCount: Int
    let isPrivate: Bool
    let isJoined: Bool
    let isOrganizer: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, organizer, title, description
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case scheduledAt = "scheduled_at"
        case maxParticipants = "max_participants"
        case participantCount = "participant_count"
        case isPrivate = "is_private"
        case isJoined = "is_joined"
        case isOrganizer = "is_organizer"
        case createdAt = "created_at"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLat, longitude: locationLng)
    }

    var isFull: Bool {
        guard let max = maxParticipants else { return false }
        return participantCount >= max
    }
}

struct MeetupParticipant: Codable, Equatable, Identifiable {
    let id: Int
    let username: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
    }
}

/// Última posición compartida por un participante mientras la quedada está
/// en marcha — sin historial, solo el punto más reciente. El backend deja
/// de devolverla pasados ~3 min sin actualizar, así que no hace falta un
/// "dejar de compartir" explícito: desaparece sola.
struct MeetupLiveLocation: Codable, Equatable, Identifiable {
    let userId: Int
    let username: String
    let avatarUrl: String?
    let lat: Double
    let lng: Double
    let updatedAt: Date

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case lat, lng
        case updatedAt = "updated_at"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
