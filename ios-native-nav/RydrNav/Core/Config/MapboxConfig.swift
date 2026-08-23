import Foundation

/// El SDK de Mapbox lee `MBXAccessToken` de Info.plist solo, pero para
/// construir URLs de la Static Images API a mano (ver `RouteMapSnapshot`)
/// necesitamos el token como string.
enum MapboxConfig {
    static let accessToken: String? = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String
}
