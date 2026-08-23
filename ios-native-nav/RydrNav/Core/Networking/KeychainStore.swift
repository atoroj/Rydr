import Foundation
import Security

/// Envoltorio mínimo sobre el Keychain — equivalente nativo de
/// `flutter_secure_storage`. Guarda el JWT y los datos de sesión.
struct KeychainStore {
    private let service = "com.rydr.rydrnav"

    func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(_ key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    func deleteAll() {
        for key in Keys.all {
            delete(key)
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    enum Keys {
        static let accessToken = "access_token"
        static let userId = "user_id"
        static let username = "username"
        static let email = "email"
        static let avatarUrl = "avatar_url"
        static let isPrivate = "is_private"
        static let all = [accessToken, userId, username, email, avatarUrl, isPrivate]
    }
}
