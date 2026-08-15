import Foundation

/// Espejo de lib/shared/models/motorbike_model.dart.
struct MotorbikeModel: Codable, Equatable, Identifiable {
    let id: Int
    let userId: Int
    let type: String
    let brand: String
    let model: String
    let cc: Int
    let alias: String?
    let year: Int?
    let photoUrl: String?
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, brand, model, cc, alias, year
        case userId = "user_id"
        case photoUrl = "photo_url"
        case isCurrent = "is_current"
    }

    /// Definir `init(from:)` abajo desactiva el memberwise init automático
    /// de Swift, así que hace falta este a mano — lo usa, por ejemplo,
    /// `RiderProfileViewController` para envolver el `MotorbikeSummary`
    /// (todo lo que expone el perfil de otro rider sobre su moto actual)
    /// en un `MotorbikeModel` completo y reutilizar `RiderGarageCell`.
    init(
        id: Int, userId: Int, type: String, brand: String, model: String, cc: Int,
        alias: String?, year: Int?, photoUrl: String?, isCurrent: Bool
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.brand = brand
        self.model = model
        self.cc = cc
        self.alias = alias
        self.year = year
        self.photoUrl = photoUrl
        self.isCurrent = isCurrent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        type = try c.decode(String.self, forKey: .type)
        brand = try c.decode(String.self, forKey: .brand)
        model = try c.decode(String.self, forKey: .model)
        cc = try c.decode(Int.self, forKey: .cc)
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        isCurrent = try c.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
    }

    var displayName: String { alias ?? "\(brand) \(model)" }
}
