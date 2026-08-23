import CoreLocation
import MapboxMaps
import UIKit

/// Descarga el mapa + los datos de rutado de la zona de una ruta para
/// poder navegarla sin conexión — carretera de montaña con cobertura mala
/// es el caso de uso real, y es un gancho de pago tanto en Calimoto como
/// en REVER.
///
/// Envuelve `OfflineManager`/`TileStore` — públicos de verdad (comprobado
/// contra las cabeceras Objective-C de los frameworks binarios que los
/// traen, no solo contra el wrapper Swift, que podría estar envolviendo
/// algo interno) — siguiendo el mismo patrón que el ejemplo oficial de
/// Mapbox (`OfflineManagerExample.swift` del propio SDK).
///
/// No hace falta tocar `RoutingProviderSource` en `RouteNavigationLauncher`
/// para que la navegación guiada funcione sin conexión: ya viene en
/// `.hybrid` por defecto (intenta online, cae a offline solo si hace
/// falta) — basta con que las teselas de mapa y de rutado estén
/// descargadas para la zona.
@MainActor
final class OfflineMapManager {
    static let shared = OfflineMapManager()

    private let offlineManager = OfflineManager()
    private let tileStore = TileStore.default

    // El mismo estilo oscuro que usa la navegación guiada de verdad
    // (ver `RydrNavigationStyle`) — no `.outdoors`, que es solo el de la
    // vista previa antes de arrancar; para navegar de verdad sin conexión
    // hace falta el que realmente se usa en pantalla completa.
    private static let navigationStyleURI = StyleURI(url: URL(string: "mapbox://styles/mapbox/dark-v11")!)!

    // Margen fijo alrededor del trazado en vez de un buffer real de la
    // polilínea — mucho más simple, y de sobra para no quedarte sin mapa
    // si te desvías un poco de la ruta original.
    private static let corridorMarginDegrees = 0.02 // ~2km

    private init() {}

    /// Identificador estable por ruta — descargarla dos veces actualiza la
    /// región existente en vez de duplicarla.
    func regionId(for route: RouteModel) -> String { "route-\(route.id)" }

    private func corridorGeometry(for route: RouteModel) -> Geometry? {
        guard !route.path.isEmpty else { return nil }
        let lats = route.path.map(\.latitude)
        let lons = route.path.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max()
        else { return nil }
        let margin = Self.corridorMarginDegrees
        let sw = CLLocationCoordinate2D(latitude: minLat - margin, longitude: minLon - margin)
        let nw = CLLocationCoordinate2D(latitude: maxLat + margin, longitude: minLon - margin)
        let ne = CLLocationCoordinate2D(latitude: maxLat + margin, longitude: maxLon + margin)
        let se = CLLocationCoordinate2D(latitude: minLat - margin, longitude: maxLon + margin)
        return .polygon(Polygon([[sw, nw, ne, se, sw]]))
    }

    /// Estilo (glifos/sprites/calles) + rutado (Map Matching/Directions
    /// offline) — los dos hacen falta para poder navegar de verdad sin
    /// conexión, no solo ver el mapa.
    private func descriptors() -> [TilesetDescriptor] {
        let styleOptions = TilesetDescriptorOptions(
            styleURI: Self.navigationStyleURI, zoomRange: 0...16, tilesets: nil)
        let styleDescriptor = offlineManager.createTilesetDescriptor(for: styleOptions)
        return [styleDescriptor, RouteNavigationLauncher.shared.navigationTilesetDescriptor()]
    }

    private func loadOptions(for route: RouteModel) -> TileRegionLoadOptions? {
        guard let geometry = corridorGeometry(for: route) else { return nil }
        return TileRegionLoadOptions(geometry: geometry, descriptors: descriptors(), acceptExpired: true)
    }

    /// Tamaño estimado antes de comprometerse a la descarga — `nil` si no
    /// se ha podido calcular (sin red, ruta sin puntos…), tratado por el
    /// llamador como "no se puede estimar, pregunta igualmente".
    func estimate(for route: RouteModel) async -> TileRegionEstimateResult? {
        guard let options = loadOptions(for: route) else { return nil }
        return await withCheckedContinuation { continuation in
            tileStore.estimateTileRegion(
                forId: regionId(for: route), loadOptions: options, estimateOptions: nil,
                progress: { _ in },
                completion: { result in continuation.resume(returning: try? result.get()) }
            )
        }
    }

    /// `progress` en 0...1. Descarga primero el paquete de estilo (glifos/
    /// sprites — sin él el mapa se ve sin texto ni iconos aunque las
    /// teselas de calles sí estén) y luego la región geográfica en sí.
    @discardableResult
    func download(for route: RouteModel, progress: @escaping (Double) -> Void) async throws -> TileRegion {
        guard let options = loadOptions(for: route) else {
            throw APIError(message: "Esta ruta no tiene puntos suficientes para descargar su zona.")
        }

        let stylePackOptions = StylePackLoadOptions(glyphsRasterizationMode: .ideographsRasterizedLocally)
        if let stylePackOptions {
            _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StylePack, Error>) in
                offlineManager.loadStylePack(for: Self.navigationStyleURI, loadOptions: stylePackOptions) { result in
                    continuation.resume(with: result)
                }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            tileStore.loadTileRegion(
                forId: regionId(for: route), loadOptions: options,
                progress: { p in
                    guard p.requiredResourceCount > 0 else { return }
                    progress(Double(p.completedResourceCount) / Double(p.requiredResourceCount))
                },
                completion: { result in continuation.resume(with: result) }
            )
        }
    }

    func downloadedRegions() async -> [TileRegion] {
        await withCheckedContinuation { continuation in
            tileStore.allTileRegions { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    func delete(regionId: String) async {
        await withCheckedContinuation { continuation in
            tileStore.removeRegion(forId: regionId) { _ in continuation.resume() }
        }
    }
}
