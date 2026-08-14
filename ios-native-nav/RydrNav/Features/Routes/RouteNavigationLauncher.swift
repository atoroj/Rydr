import CoreLocation
import MapboxDirections
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// Envía el track grabado de una ruta a la Mapbox Map Matching API y arranca
/// la navegación guiada del SDK — a diferencia de Directions API, respeta tu
/// trazado exacto en vez de calcular el camino "óptimo" entre origen y
/// destino. Compartido por la pantalla de detalle de ruta.
///
/// `startWithApproach` añade delante un primer tramo con Directions normal
/// (sí "óptimo", a propósito) desde la posición actual hasta el punto de
/// inicio del trazado guardado — la "ruta de aproximación" del spec. Al
/// llegar, se cierra esa guía y se encadena automáticamente `start`, que
/// sigue siendo el trazado exacto sin tocar.
@MainActor
final class RouteNavigationLauncher: NSObject {
    static let shared = RouteNavigationLauncher()

    // Si ya estás a menos de esta distancia del inicio del trazado, no
    // merece la pena un tramo de aproximación aparte.
    private static let approachThresholdMeters: CLLocationDistance = 40

    // Punto de entrada del SDK de Navigation. Se crea una sola vez.
    private lazy var navigationProvider = MapboxNavigationProvider(coreConfig: .init())
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    // Estado del tramo de aproximación en curso: qué ruta guardada arrancar
    // (con el flujo exacto de siempre) en cuanto se llegue al final.
    private var pendingRoute: RouteModel?
    private var pendingPresenter: UIViewController?

    override private init() {
        super.init()
        locationManager.delegate = self
    }

    /// Punto de entrada desde `RouteDetailViewController`: decide si hace
    /// falta tramo de aproximación o se puede ir directo al trazado exacto.
    /// El tramo de aproximación es un "nice to have": si no se puede pedir
    /// la posición actual o falla el cálculo de Directions (sin red, sin
    /// permiso, API caída...) no bloquea nada — se cae directamente al
    /// seguimiento exacto de siempre, que es lo importante.
    func startWithApproach(route: RouteModel, presentingFrom viewController: UIViewController) async throws {
        guard let routeStart = route.path.first else {
            throw APIError(message: "Esta ruta no tiene puntos suficientes.")
        }

        ensureLocationAuthorization()

        if let current = await currentLocation(),
           CLLocation(latitude: current.latitude, longitude: current.longitude)
               .distance(from: CLLocation(latitude: routeStart.latitude, longitude: routeStart.longitude))
               > Self.approachThresholdMeters,
           let approachRoutes = try? await calculateApproachRoutes(from: current, to: routeStart)
        {
            pendingRoute = route
            pendingPresenter = viewController
            present(navigationRoutes: approachRoutes, delegate: self, from: viewController)
        } else {
            try await start(route: route, presentingFrom: viewController)
        }
    }

    /// Geometría + distancia/tiempo del tramo de aproximación, para
    /// dibujarlo y mostrarlo en `RoutePreviewViewController` antes de
    /// arrancar la guía de verdad. `nil` si no hace falta aproximación
    /// (ya estás cerca del inicio) o si no se puede calcular — en ambos
    /// casos la vista previa cae a mostrar solo el trazado de la ruta.
    struct ApproachPreview {
        let coordinates: [CLLocationCoordinate2D]
        let distanceMeters: CLLocationDistance
        let durationSeconds: TimeInterval
    }

    func previewApproach(to routeStart: CLLocationCoordinate2D) async -> ApproachPreview? {
        ensureLocationAuthorization()
        guard let current = await currentLocation() else { return nil }

        let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
            .distance(from: CLLocation(latitude: routeStart.latitude, longitude: routeStart.longitude))
        guard distance > Self.approachThresholdMeters,
              let navigationRoutes = try? await calculateApproachRoutes(from: current, to: routeStart)
        else { return nil }

        let route = navigationRoutes.mainRoute.route
        return ApproachPreview(
            coordinates: route.shape?.coordinates ?? [current, routeStart],
            distanceMeters: route.distance,
            durationSeconds: route.expectedTravelTime
        )
    }

    /// Pide permiso de localización si todavía no se ha pedido nunca —
    /// `requestLocation()` falla en silencio (sin mostrar el diálogo del
    /// sistema) si no se ha llamado antes a uno de los `request*Authorization`.
    private func ensureLocationAuthorization() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Guía Map Matching sobre el trazado exacto — sin cambios respecto a
    /// la versión anterior, ahora usada tanto directamente como encadenada
    /// tras la aproximación.
    func start(route: RouteModel, presentingFrom viewController: UIViewController) async throws {
        guard route.path.count >= 2 else {
            throw APIError(message: "Esta ruta no tiene puntos suficientes.")
        }
        let navigationRoutes = try await matchToNavigationRoutes(coordinates: route.path)
        present(navigationRoutes: navigationRoutes, delegate: nil, from: viewController)
    }

    // MARK: - Posición actual (para decidir/calcular la aproximación)

    private func currentLocation() async -> CLLocationCoordinate2D? {
        if let cached = locationManager.location?.coordinate { return cached }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Cálculo de rutas

    private func calculateApproachRoutes(
        from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D
    ) async throws -> NavigationRoutes {
        let waypoints = [Waypoint(coordinate: origin), Waypoint(coordinate: destination)]
        let options = RouteOptions(waypoints: waypoints)
        options.includesSteps = true
        options.includesVisualInstructions = true
        options.includesSpokenInstructions = true
        options.locale = Locale(identifier: "es")

        let routingProvider = navigationProvider.mapboxNavigation.routingProvider()
        return try await routingProvider.calculateRoutes(options: options).value
    }

    private func matchToNavigationRoutes(coordinates: [CLLocationCoordinate2D]) async throws -> NavigationRoutes {
        // La API solo acepta hasta 100 puntos; muestreamos uniformemente
        // conservando extremos, igual que en el lado Flutter.
        let sampled = downsample(coordinates, maxPoints: 100)

        // Cada `Waypoint` nace con `separatesLegs = true`: el SDK lo trata
        // como una parada real (tramo propio, marcador, "llegada"...). Con
        // 100 puntos así, la ruta se trocea en ~99 tramos minúsculos — de
        // ahí el collar de marcadores en el mapa y que no salgan
        // indicaciones de giro de verdad. Solo el primer y el último punto
        // son paradas reales; el resto son puntos de forma para que el
        // trazado siga tu recorrido exacto, no paradas.
        let waypoints = sampled.enumerated().map { index, coordinate -> Waypoint in
            var waypoint = Waypoint(coordinate: coordinate)
            waypoint.separatesLegs = (index == 0 || index == sampled.count - 1)
            return waypoint
        }

        let matchOptions = MatchOptions(waypoints: waypoints)
        matchOptions.includesSteps = true
        // Sin esto, la API solo manda el texto plano de `maneuver.instruction`
        // (útil para depurar por curl) pero NO el `VisualInstructionBanner`
        // que pinta el icono+calle del banner superior, ni las instrucciones
        // de voz que necesita el TTS. Los dos "faltaban" por el mismo motivo.
        matchOptions.includesVisualInstructions = true
        matchOptions.includesSpokenInstructions = true
        matchOptions.locale = Locale(identifier: "es")

        let routingProvider = navigationProvider.mapboxNavigation.routingProvider()
        return try await routingProvider.calculateRoutes(options: matchOptions).value
    }

    private func downsample(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let step = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { coordinates[Int((Double($0) * step).rounded())] }
    }

    // MARK: - Presentación

    private func present(navigationRoutes: NavigationRoutes, delegate: NavigationViewControllerDelegate?, from viewController: UIViewController) {
        // Mapa de navegación con la línea de ruta en el naranja de marca en
        // vez del azul por defecto del SDK. Los colores de congestión
        // (moderado/denso/severo) se dejan tal cual — son señalización de
        // tráfico real, no parte del branding.
        let navigation = navigationProvider.mapboxNavigation.navigation()
        let brandedMapView = NavigationMapView(
            location: navigation.locationMatching.map { $0.enhancedLocation }.eraseToAnyPublisher(),
            routeProgress: navigation.routeProgress.map { $0?.routeProgress }.eraseToAnyPublisher(),
            heading: navigation.heading,
            predictiveCacheManager: nil
        )
        // `routeColor` por sí solo únicamente sobreescribe los niveles de
        // tráfico "bajo"/"desconocido" — deja "moderado/denso/severo" con
        // los colores por defecto del SDK. La aproximación (Directions
        // sobre carreteras reales) puede traer tramos con tráfico real, así
        // que sin esto se veían de otro color que el trazado exacto (que,
        // al venir de Map Matching, nunca trae datos de tráfico). Fijamos
        // todos los niveles al naranja de marca para que sea un único color
        // consistente en toda la guía, en los dos tramos.
        let brandColors = CongestionColorsConfiguration.Colors(
            low: AppTheme.primary, moderate: AppTheme.primary, heavy: AppTheme.primary,
            severe: AppTheme.primary, unknown: AppTheme.primary
        )
        brandedMapView.congestionConfiguration.colors = CongestionColorsConfiguration(
            mainRouteColors: brandColors, alternativeRouteColors: brandColors
        )
        brandedMapView.routeCasingColor = AppTheme.primary.withAlphaComponent(0.6)
        brandedMapView.maneuverArrowColor = AppTheme.primary

        let navigationOptions = NavigationOptions(
            mapboxNavigation: navigationProvider.mapboxNavigation,
            voiceController: navigationProvider.routeVoiceController,
            eventsManager: navigationProvider.eventsManager(),
            styles: [RydrDayStyle(), RydrNightStyle()],
            navigationMapView: brandedMapView
        )
        let navigationViewController = NavigationViewController(
            navigationRoutes: navigationRoutes,
            navigationOptions: navigationOptions
        )
        navigationViewController.delegate = delegate
        navigationViewController.modalPresentationStyle = .fullScreen
        viewController.present(navigationViewController, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate (posición actual, one-shot)

extension RouteNavigationLauncher: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last?.coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - NavigationViewControllerDelegate (fin del tramo de aproximación)

extension RouteNavigationLauncher: NavigationViewControllerDelegate {
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) {
        guard let route = pendingRoute, let presenter = pendingPresenter else { return }
        pendingRoute = nil
        pendingPresenter = nil

        navigationViewController.dismiss(animated: true) {
            Task { try? await self.start(route: route, presentingFrom: presenter) }
        }
    }

    /// Sin esto, el botón de cancelar/X del tramo de aproximación no hacía
    /// nada. El SDK decide si se cierra solo mirando si la llamada al
    /// delegado devolvió `nil`: `delegate?.navigationViewControllerDidDismiss(...)`
    /// es de tipo `Void?`, y en Swift eso da "no nil" en cuanto hay
    /// delegado — aunque el método no haga nada — así que por tener
    /// delegado (necesario para saber cuándo se llega al inicio) el SDK
    /// asume "ya se encarga la app de cerrarlo" y se queda quieto.
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        // Si se cancela la aproximación a medias, no se sigue con el
        // trazado exacto después.
        pendingRoute = nil
        pendingPresenter = nil
        navigationViewController.dismiss(animated: true)
    }
}
