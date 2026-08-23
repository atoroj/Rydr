import CoreLocation
import Foundation

/// Espejo de `RouteModel` (lib/shared/models/route_model.dart) — mismo
/// backend, mismo JSON, sin tocar nada del lado Flutter.
struct RouteModel: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let description: String?
    let authorId: Int
    let geojson: GeoJSONLineString
    let distanceKm: Double
    let durationMinutes: Int
    let timesRidden: Int
    let coverImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case authorId = "author_id"
        case geojson
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case timesRidden = "times_ridden"
        case coverImageUrl = "cover_image_url"
    }

    /// Todos los puntos seguidos, sin distinguir tramos — para lo que no
    /// necesita saber dónde hubo una pausa (bounding box de mapas
    /// offline, entrada al Map Matching de Mapbox para sacar los giros:
    /// ya tiene su propio aviso de "trazado incompleto" si no encuentra
    /// una carretera continua, ver `RouteNavigationLauncher`).
    var path: [CLLocationCoordinate2D] {
        geojson.segments.flatMap { $0.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } }
    }

    /// Los mismos puntos, agrupados por tramo real — separados donde se
    /// pausó la grabación. Para lo que sí dibuja el mapa (detalle,
    /// preview, miniaturas, exportar GPX): dibujar cada tramo por
    /// separado evita conectar el hueco de una pausa con una línea recta,
    /// como si fuera carretera recorrida.
    var segments: [[CLLocationCoordinate2D]] {
        geojson.segments.map { $0.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } }
    }
}

/// Un `LineString` de GeoJSON es un único tramo; un `MultiLineString` es
/// varios tramos separados (ver `RegisterViewController.trackSegments` —
/// el hueco entre dos tramos es una pausa en la grabación). Los dos casos
/// se guardan aquí en la misma forma interna (`segments`, siempre no
/// vacía) para que el resto de la app no tenga que distinguir cuál es
/// cuál — un `LineString` de toda la vida sigue decodificando a
/// `segments.count == 1`, cero cambio de comportamiento para las rutas ya
/// existentes (todas sin pausas, grabadas antes de esta función).
struct GeoJSONLineString: Codable, Equatable {
    let type: String
    /// Cada elemento es un tramo (lista de `[lon, lat]`).
    let segments: [[[Double]]]

    enum CodingKeys: String, CodingKey { case type, coordinates }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "LineString"
        self.type = type
        if type == "MultiLineString" {
            segments = try container.decode([[[Double]]].self, forKey: .coordinates)
        } else {
            let flat = try container.decode([[Double]].self, forKey: .coordinates)
            segments = [flat]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if type == "MultiLineString" {
            try container.encode(segments, forKey: .coordinates)
        } else {
            try container.encode(segments.first ?? [], forKey: .coordinates)
        }
    }
}
