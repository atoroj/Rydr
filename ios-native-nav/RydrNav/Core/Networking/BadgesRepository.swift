import Foundation

/// Espejo de app/badges/infrastructure/badge_router.py.
struct BadgesRepository {
    private let client = APIClient.shared

    func badges(userId: Int) async throws -> [BadgeModel] {
        try await client.request(.get, "\(APIConstants.riders)/\(userId)/badges")
    }
}
