import CoreLocation

/// Algoritmo estándar de "encoded polyline" (precisión 5) — el mismo que
/// usan Google Maps y la Static Images API de Mapbox para el overlay
/// `path-...(...)`. Usado por `RouteMapSnapshot`.
enum PolylineEncoder {
    static func encode(_ coordinates: [CLLocationCoordinate2D], precision: Double = 1e5) -> String {
        var output = ""
        var previousLat = 0
        var previousLng = 0

        for coordinate in coordinates {
            let lat = Int((coordinate.latitude * precision).rounded())
            let lng = Int((coordinate.longitude * precision).rounded())
            output += encodeValue(lat - previousLat)
            output += encodeValue(lng - previousLng)
            previousLat = lat
            previousLng = lng
        }
        return output
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value << 1
        if value < 0 { v = ~v }

        var output = ""
        while v >= 0x20 {
            let chunk = (0x20 | (v & 0x1f)) + 63
            output.unicodeScalars.append(UnicodeScalar(chunk)!)
            v >>= 5
        }
        output.unicodeScalars.append(UnicodeScalar(v + 63)!)
        return output
    }
}
