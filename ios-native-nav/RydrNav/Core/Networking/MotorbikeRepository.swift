import Foundation

/// Espejo de lib/features/motorbikes/data/motorbike_repository.dart.
struct MotorbikeRepository {
    private let client = APIClient.shared

    func getMotorbikes(userId: Int) async throws -> [MotorbikeModel] {
        try await client.request(.get, "\(APIConstants.motorbikes)/user/\(userId)")
    }

    func createMotorbike(
        userId: Int, type: String, brand: String, model: String, cc: Int,
        alias: String?, year: Int? = nil, photoUrl: String? = nil
    ) async throws -> MotorbikeModel {
        var body: [String: Any] = [
            "user_id": userId, "type": type, "brand": brand, "model": model, "cc": cc,
        ]
        if let alias { body["alias"] = alias }
        if let year { body["year"] = year }
        if let photoUrl { body["photo_url"] = photoUrl }
        return try await client.request(.post, APIConstants.motorbikes, body: body)
    }

    /// Marca [motorbikeId] como la moto actual (garaje virtual): la que
    /// aparece en el perfil social y en el listado de Riders.
    func setCurrent(motorbikeId: Int) async throws -> MotorbikeModel {
        try await client.request(.post, "\(APIConstants.motorbikes)/\(motorbikeId)/set-current")
    }

    func updateMotorbike(
        id: Int, type: String? = nil, brand: String? = nil, model: String? = nil, cc: Int? = nil,
        alias: String? = nil, year: Int? = nil, photoUrl: String? = nil
    ) async throws -> MotorbikeModel {
        var body: [String: Any] = [:]
        if let type { body["type"] = type }
        if let brand { body["brand"] = brand }
        if let model { body["model"] = model }
        if let cc { body["cc"] = cc }
        if let alias { body["alias"] = alias }
        if let year { body["year"] = year }
        if let photoUrl { body["photo_url"] = photoUrl }
        return try await client.request(.patch, "\(APIConstants.motorbikes)/\(id)", body: body)
    }

    func deleteMotorbike(id: Int) async throws {
        try await client.requestVoid(.delete, "\(APIConstants.motorbikes)/\(id)")
    }
}
