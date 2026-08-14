import Foundation

/// Espejo de lib/shared/models/user_model.dart — mismo backend, mismo JSON.
struct UserModel: Codable, Equatable {
    let id: Int
    let username: String
    let email: String
    var avatarUrl: String?
    var isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case avatarUrl = "avatar_url"
        case isPrivate = "is_private"
    }

    init(id: Int, username: String, email: String, avatarUrl: String? = nil, isPrivate: Bool = false) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarUrl = avatarUrl
        self.isPrivate = isPrivate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        email = try c.decode(String.self, forKey: .email)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
    }
}
