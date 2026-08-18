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

    /// `segments`: cada tramo del trazado por separado (ver
    /// `RouteModel.segments`) — un tramo sin pausas es un único elemento,
    /// cero cambio respecto a antes. Con más de uno, se manda un overlay
    /// `path-...(...)` por tramo (la Static Images API admite varios,
    /// separados por coma, en la misma URL) para no dibujar una línea recta
    /// uniendo el hueco de una pausa.
    static func url(for segments: [[CLLocationCoordinate2D]], width: Int = 600, height: Int = 300) -> URL? {
        let realSegments = segments.filter { $0.count >= 2 }
        guard !realSegments.isEmpty, let token = MapboxConfig.accessToken else { return nil }

        let totalPoints = realSegments.reduce(0) { $0 + $1.count }
        let overlays = realSegments.compactMap { segment -> String? in
            // Presupuesto de puntos repartido a prorrata del tamaño de
            // cada tramo, con un mínimo de 2 (los extremos) para que un
            // tramo corto no se quede sin overlay por redondeo.
            let share = max(2, Int((Double(segment.count) / Double(totalPoints)) * Double(maxOverlayPoints)))
            let sampled = downsample(segment, maxPoints: share)
            let polyline = PolylineEncoder.encode(sampled)
            guard let encodedPolyline = polyline.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
                return nil
            }
            // Naranja de marca Hi-Vis (AppTheme.primary, #FFB020) sin '#',
            // tal como lo pide el overlay `path-{width}+{color}-{opacity}(...)`.
            return "path-4+ffb020-1(\(encodedPolyline))"
        }
        guard !overlays.isEmpty else { return nil }

        let urlString = "https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/\(overlays.joined(separator: ","))"
            + "/auto/\(width)x\(height)@2x?padding=30&access_token=\(token)"
        return URL(string: urlString)
    }

    private static func downsample(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let step = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { coordinates[Int((Double($0) * step).rounded())] }
    }
}
