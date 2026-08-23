import CoreLocation
import Foundation

/// Genera la URL de una imagen estática (Mapbox Static Images API) centrada
/// en un único punto con una chincheta ámbar encima — usada como miniatura
/// del punto de encuentro en las tarjetas de Quedadas. Hermano de
/// `RouteMapSnapshot`, que hace lo mismo pero con un trazado en vez de un
/// punto.
enum PinMapSnapshot {
    static func url(for coordinate: CLLocationCoordinate2D, width: Int = 600, height: Int = 220, zoom: Double = 13) -> URL? {
        guard let token = MapboxConfig.accessToken else { return nil }
        let marker = "pin-s+ffb020(\(coordinate.longitude),\(coordinate.latitude))"
        let urlString = "https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/\(marker)"
            + "/\(coordinate.longitude),\(coordinate.latitude),\(zoom),0/\(width)x\(height)@2x?access_token=\(token)"
        return URL(string: urlString)
    }
}
