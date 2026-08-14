import CoreLocation
import Foundation

/// Genera la URL de una imagen estática (Mapbox Static Images API) con el
/// trazado real de la ruta dibujado encima — usada como miniatura de las
/// tarjetas de ruta. El usuario pidió expresamente ver "el mapa con la
/// ruta", no la foto que se sube al publicar (esa se enseña en el detalle,
/// ver `RouteDetailViewController`).
enum RouteMapSnapshot {
    // La Static Images API tiene un límite de longitud de URL; con esto de
    // sobra para que el trazado se reconozca en una miniatura.
    private static let maxOverlayPoints = 100

    static func url(for coordinates: [CLLocationCoordinate2D], width: Int = 600, height: Int = 300) -> URL? {
        guard coordinates.count >= 2, let token = MapboxConfig.accessToken else { return nil }

        let sampled = downsample(coordinates, maxPoints: maxOverlayPoints)
        let polyline = PolylineEncoder.encode(sampled)
        guard let encodedPolyline = polyline.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return nil
        }

        // Naranja de marca (AppTheme.primary) sin '#', tal como lo pide el
        // overlay `path-{width}+{color}-{opacity}(...)`.
        let overlay = "path-4+e8501a-1(\(encodedPolyline))"
        let urlString = "https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/\(overlay)"
            + "/auto/\(width)x\(height)@2x?padding=30&access_token=\(token)"
        return URL(string: urlString)
    }

    private static func downsample(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let step = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { coordinates[Int((Double($0) * step).rounded())] }
    }
}
