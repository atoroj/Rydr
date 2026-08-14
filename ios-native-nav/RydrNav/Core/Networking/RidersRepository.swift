import Foundation

/// Espejo de app/riders/infrastructure/follow_router.py (`/riders/...`).
struct RidersRepository {
    private let client = APIClient.shared

    func search(query: String) async throws -> [RiderSummary] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.request(.get, "\(APIConstants.riders)/search?q=\(encoded)")
    }

    func follow(userId: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.riders)/\(userId)/follow")
    }

    func unfollow(userId: Int) async throws {
        try await client.requestVoid(.delete, "\(APIConstants.riders)/\(userId)/unfollow")
    }

    func accept(requestId: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.riders)/requests/\(requestId)/accept")
    }

    func reject(requestId: Int) async throws {
        try await client.requestVoid(.post, "\(APIConstants.riders)/requests/\(requestId)/reject")
    }

    func following() async throws -> [RiderSummary] {
        try await client.request(.get, "\(APIConstants.riders)/following")
    }

    func followers() async throws -> [RiderSummary] {
        try await client.request(.get, "\(APIConstants.riders)/followers")
    }

    func pendingRequests() async throws -> [FollowRequest] {
        try await client.request(.get, "\(APIConstants.riders)/requests")
    }

    func profile(userId: Int) async throws -> RiderProfile {
        try await client.request(.get, "\(APIConstants.riders)/\(userId)/profile")
    }

    /// Portada de la app: rutas publicadas por la gente que sigues, más
    /// recientes primero.
    func feed() async throws -> [FeedItem] {
        try await client.request(.get, "\(APIConstants.riders)/feed")
    }
}
