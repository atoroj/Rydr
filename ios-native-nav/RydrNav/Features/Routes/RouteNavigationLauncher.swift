import Combine
import CoreLocation
import MapboxDirections
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// Envía tu posición actual + el track grabado de una ruta (o su reverso,
/// según elijas) a la Mapbox Map Matching API en una única llamada, y
/// arranca UNA sola navegación guiada de principio a fin — sin ventanas
/// intermedias ni cambios de pantalla. Antes había dos fases encadenadas
/// (un tramo de aproximación con Directions normal + el trazado exacto con
/// Map Matching, cada una su propio `NavigationViewController`, con un
/// cierre/reapertura al llegar al inicio); se fusionaron en una porque:
/// - Se notaba el salto de ventana al pasar de una fase a otra.
/// - La aproximación, al ir por Directions normal en vez de Map Matching,
///   no tenía por qué salir con la misma fidelidad que el trazado exacto.
///
/// Con una sola llamada de Map Matching cubriendo "tu posición → todo el
/// trazado guardado", las dos cosas quedan resueltas por construcción: es
/// literalmente el mismo pipeline (mismo Douglas-Peucker, misma API) para
/// todo el trayecto, así que no hay una fase "peor" que la otra.
///
/// La línea que se ve en el mapa es la geometría que devuelve el propio
/// matching (dibujada por `NavigationMapView`, sin overlay nuestro
/// encima) — se probó pintar el trazado grabado tal cual, punto a punto,
/// pero esa línea conecta puntos consecutivos con tramos rectos sin
/// interpolar la curva real entre medias: en una curva cerrada donde el
/// siguiente punto grabado ya gira bastante, esa recta se nota aunque el
/// matching de debajo siga bien la carretera. La geometría "enganchada"
/// del propio SDK trae muchos más puntos interpolados a lo largo de la
/// carretera real, así que sigue las curvas mejor que unir a mano los
/// puntos grabados — el hueco real (comprobado con rutas de verdad: Map
/// Matching a veces no encaja algún tramo, ni afinando el muestreo ni el
/// radio de búsqueda) es aparte y se avisa con `showTruncatedRouteWarning`.
@MainActor
final class RouteNavigationLauncher: NSObject {
    static let shared = RouteNavigationLauncher()

    // Si ya estás a menos de esta distancia del punto de partida elegido,
    // no merece la pena meter tu posición actual como punto de más — ya
    // estás prácticamente encima.
    private static let approachThresholdMeters: CLLocationDistance = 40

    // Punto de entrada del SDK de Navigation. Se crea una sola vez.
    private lazy var navigationProvider = MapboxNavigationProvider(coreConfig: .init())
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    /// Descriptor de teselas de rutado (Directions/Map Matching offline) —
    /// lo usa `OfflineMapManager` para combinarlo con el descriptor de
    /// estilo al preparar una descarga. Se expone solo esto, no
    /// `navigationProvider` entero: reutiliza la única instancia de
    /// `MapboxNavigationProvider` de la app en vez de que otra pantalla
    /// tenga que crear una segunda (cara, y probablemente conflictiva con
    /// el motor nativo de navegación).
    func navigationTilesetDescriptor() -> TilesetDescriptor {
        navigationProvider.getLatestNavigationTilesetDescriptor()
    }

    override private init() {
        super.init()
        locationManager.delegate = self
    }

    /// Punto de entrada desde `RoutePreviewViewController`. `reversed`
    /// decide si el trazado guardado se recorre desde su primer punto
    /// grabado o desde el último (para cuando te pilla más cerca del final
    /// que del principio, o simplemente prefieres hacerla al revés).
    func start(route: RouteModel, reversed: Bool, presentingFrom viewController: UIViewController) async throws {
        guard route.path.count >= 2 else {
            throw APIError(message: "Esta ruta no tiene puntos suficientes.")
        }
        ensureLocationAuthorization()

        let orderedPath = reversed ? Array(route.path.reversed()) : route.path
        var coordinates = orderedPath
        // Punto de partida "en vivo", no grabado — si estás lejos, se mete
        // delante para que la propia llamada de matching calcule el camino
        // real hasta el trazado, en vez de arrancar la guía ya sobre el
        // trazado y dejarte "teletransportado" hasta él.
        var prependedLiveLocation = false
        if let current = await currentLocation(),
           CLLocation(latitude: current.latitude, longitude: current.longitude)
               .distance(from: CLLocation(latitude: orderedPath[0].latitude, longitude: orderedPath[0].longitude))
               > Self.approachThresholdMeters
        {
            coordinates.insert(current, at: 0)
            prependedLiveLocation = true
        }

        let navigationRoutes = try await matchToNavigationRoutes(
            coordinates: coordinates, generousRadiusForFirstPoint: prependedLiveLocation)
        present(navigationRoutes: navigationRoutes, from: viewController)

        // La Map Matching API a veces no logra encajar todo el trazado en
        // un único tramo continuo y de fiar (comprobado: no es cuestión de
        // radio de búsqueda, se probó ampliándolo y seguía partiéndolo —
        // sencillamente no encuentra una carretera continua para ese
        // hueco). Cuando pasa, `NavigationRoutes` solo guía por el primer
        // tramo y convierte el resto en "rutas alternativas" (ya no se
        // dibujan, ver `showsAlternatives` más abajo, pero la guía sigue
        // sin cubrir ese tramo final) — mejor avisar que dejarlo en
        // silencio, como con el resto de fallos de esta pantalla.
        if !navigationRoutes.alternativeRoutes.isEmpty {
            showTruncatedRouteWarning(from: viewController)
        }
    }

    private func showTruncatedRouteWarning(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Trazado incompleto",
            message: "No se ha podido calcular un camino de carretera continuo para toda la ruta grabada. "
                + "La guía puede terminar antes del final del trazado.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Entendido", style: .default))
        // El aviso va sobre lo que esté presentado en ese momento — normalmente
        // el propio `NavigationViewController` recién presentado.
        (viewController.presentedViewController ?? viewController).present(alert, animated: true)
    }

    /// Geometría + distancia/tiempo desde tu posición hasta el punto de
    /// partida elegido (principio o final del trazado), para mostrarlo en
    /// `RoutePreviewViewController` antes de arrancar la guía de verdad.
    /// Usa Directions normal (no Map Matching) solo para esta estimación
    /// — es más barato y de sobra para un cálculo informativo; la guía
    /// real usa la llamada unificada de arriba. `nil` si no hace falta
    /// (ya estás cerca) o si no se puede calcular — en ambos casos la
    /// vista previa cae a mostrar solo el trazado de la ruta.
    struct ApproachPreview {
        let coordinates: [CLLocationCoordinate2D]
        let distanceMeters: CLLocationDistance
        let durationSeconds: TimeInterval
    }

    func previewApproach(to startingPoint: CLLocationCoordinate2D) async -> ApproachPreview? {
        ensureLocationAuthorization()
        guard let current = await currentLocation() else { return nil }

        let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
            .distance(from: CLLocation(latitude: startingPoint.latitude, longitude: startingPoint.longitude))
        guard distance > Self.approachThresholdMeters,
              let navigationRoutes = try? await calculateApproachPreviewRoute(from: current, to: startingPoint)
        else { return nil }

        let route = navigationRoutes.mainRoute.route
        return ApproachPreview(
            coordinates: route.shape?.coordinates ?? [current, startingPoint],
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

    // MARK: - Posición actual (para decidir/calcular el punto de partida)

    private func currentLocation() async -> CLLocationCoordinate2D? {
        if let cached = locationManager.location?.coordinate { return cached }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Cálculo de rutas

    private func calculateApproachPreviewRoute(
        from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D
    ) async throws -> NavigationRoutes {
        let waypoints = [Waypoint(coordinate: origin), Waypoint(coordinate: destination)]
        let options = RouteOptions(waypoints: waypoints)
        options.includesSteps = true
        options.includesVisualInstructions = true
        options.includesSpokenInstructions = true
        options.locale = Locale(identifier: "es")
        // Encontrada la causa real del corte en curvas: `routeShapeResolution`
        // por defecto es `.low` ("simplified") — la propia documentación del
        // SDK dice que esa resolución "carece del detalle necesario para
        // fijarse en tramos individuales de la ruta". `.full` es "equivalente
        // a concatenar la forma de todos los `steps`" — la misma fuente que
        // ya usa la flecha de maniobra (siempre a resolución completa,
        // independientemente de este ajuste, por eso a ella nunca le pasaba).
        options.routeShapeResolution = .full

        let routingProvider = navigationProvider.mapboxNavigation.routingProvider()
        return try await routingProvider.calculateRoutes(options: options).value
    }

    private func matchToNavigationRoutes(
        coordinates: [CLLocationCoordinate2D], generousRadiusForFirstPoint: Bool
    ) async throws -> NavigationRoutes {
        // La API solo acepta hasta 100 puntos; simplificamos con
        // Douglas-Peucker conservando las curvas (ver más abajo) en vez de
        // muestrear a ciegas.
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
            // El primer punto, cuando es tu posición en vivo (no un punto
            // grabado del trazado), puede tener bastante error de GPS y no
            // caer justo sobre la carretera — un radio de búsqueda estrecho
            // (el que usa la API por defecto) puede hacer fallar el
            // matching justo en ese primer salto. Los puntos grabados del
            // trazado no lo necesitan: ya están limpios y cerca de la
            // carretera real.
            if index == 0 && generousRadiusForFirstPoint {
                waypoint.coordinateAccuracy = 50
            }
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
        // Ver el comentario en `calculateApproachPreviewRoute` — la causa
        // real del corte en curvas era esta, no el muestreo ni el radio de
        // búsqueda: `routeShapeResolution` por defecto es `.low`.
        matchOptions.routeShapeResolution = .full
        matchOptions.locale = Locale(identifier: "es")

        let routingProvider = navigationProvider.mapboxNavigation.routingProvider()
        return try await routingProvider.calculateRoutes(options: matchOptions).value
    }

    /// Antes cogía 1 punto de cada N a intervalos regulares — a ciegas, sin
    /// mirar si ese tramo era una recta o una curva cerrada. En una ruta
    /// larga (miles de puntos en varias horas) eso podía tirar justo los
    /// puntos que dibujan una curva, y a la Map Matching API solo le
    /// llegaban los dos extremos — con lo que interpolaba el camino más
    /// directo entre ellos, cortando la curva de un tirón.
    ///
    /// Aquí en vez de eso se simplifica el trazado con Douglas-Peucker: un
    /// punto solo se tira si está casi sobre la línea recta entre sus
    /// vecinos que sí se conservan — en un tramo recto eso son casi todos,
    /// pero en una curva cerrada ninguno se aleja lo bastante de esa recta
    /// como para poder quitarlo. El presupuesto de 100 puntos (límite duro
    /// de la API) se gasta así donde de verdad hace falta, no de forma
    /// pareja.
    private func downsample(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        // Se sube el margen de tolerancia poco a poco hasta que el
        // trazado simplificado quepa en el límite — así se conserva el
        // máximo detalle posible dentro de los 100 puntos permitidos, en
        // vez de fijar a mano una tolerancia que podría quedarse corta
        // (ruta con muchas curvas) o pasarse (ruta mayormente recta).
        var epsilonMeters: Double = 2
        var simplified = Self.douglasPeucker(coordinates, epsilonMeters: epsilonMeters)
        while simplified.count > maxPoints {
            epsilonMeters *= 1.6
            simplified = Self.douglasPeucker(coordinates, epsilonMeters: epsilonMeters)
        }
        return simplified
    }

    /// Versión iterativa (pila explícita, no recursión) para no arriesgar
    /// la pila de llamadas con rutas de miles de puntos.
    private static func douglasPeucker(_ points: [CLLocationCoordinate2D], epsilonMeters: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true

        var stack: [(start: Int, end: Int)] = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }
            var maxDistance: Double = 0
            var splitIndex = start
            for i in (start + 1)..<end {
                let distance = perpendicularDistanceMeters(points[i], lineStart: points[start], lineEnd: points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    splitIndex = i
                }
            }
            if maxDistance > epsilonMeters {
                keep[splitIndex] = true
                stack.append((start, splitIndex))
                stack.append((splitIndex, end))
            }
        }
        return points.enumerated().compactMap { keep[$0.offset] ? $0.element : nil }
    }

    /// Distancia perpendicular de `point` a la recta `lineStart`–`lineEnd`,
    /// en metros — proyección equirectangular local (suficiente para el
    /// tramo corto entre dos puntos consecutivos del trazado, no para
    /// distancias largas donde la curvatura de la Tierra ya pesa).
    private static func perpendicularDistanceMeters(
        _ point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(lineStart.latitude * .pi / 180)
        func toXY(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (x: c.longitude * metersPerDegreeLon, y: c.latitude * metersPerDegreeLat)
        }
        let p = toXY(point), a = toXY(lineStart), b = toXY(lineEnd)
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projX = a.x + t * dx, projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }

    // MARK: - Presentación

    private func present(navigationRoutes: NavigationRoutes, from viewController: UIViewController) {
        // Mapa de navegación con la línea de ruta en el naranja de marca en
        // vez del azul por defecto del SDK. Los colores de congestión
        // (moderado/denso/severo) se dejan tal cual — son señalización de
        // tráfico real, no parte del branding.
        let navigation = navigationProvider.mapboxNavigation.navigation()
        let brandedMapView = NavigationMapView(
            location: navigation.locationMatching.map { $0.enhancedLocation }.eraseToAnyPublisher(),
            routeProgress: navigation.routeProgress.map { $0?.routeProgress }.eraseToAnyPublisher(),
            // El init sin `routeRefreshing:` está obsoleto. El propio SDK
            // lo calcula internamente comparando rutas consecutivas, pero
            // esa comparación (`NavigationRoutes.areRefreshed`) es interna
            // del framework, no la podemos llamar desde aquí — un
            // publisher vacío (sin refrescos "en directo" de tráfico) es
            // la alternativa pública más cercana, y no perdemos nada que
            // ya estuviéramos usando antes (no dependíamos de ese evento).
            routeRefreshing: Empty<RefreshingStatus, Never>().eraseToAnyPublisher(),
            heading: navigation.heading,
            predictiveCacheManager: nil
        )
        // `routeColor` por sí solo únicamente sobreescribe los niveles de
        // tráfico "bajo"/"desconocido" — deja "moderado/denso/severo" con
        // los colores por defecto del SDK. Fijamos todos los niveles al
        // naranja de marca para que sea un único color consistente en toda
        // la guía.
        let brandColors = CongestionColorsConfiguration.Colors(
            low: AppTheme.primary, moderate: AppTheme.primary, heavy: AppTheme.primary,
            severe: AppTheme.primary, unknown: AppTheme.primary
        )
        brandedMapView.congestionConfiguration.colors = CongestionColorsConfiguration(
            mainRouteColors: brandColors, alternativeRouteColors: brandColors
        )
        brandedMapView.routeCasingColor = AppTheme.primary.withAlphaComponent(0.6)
        brandedMapView.maneuverArrowColor = AppTheme.primary
        // Cuando la Map Matching API no logra encajar todo el trazado en
        // un único tramo continuo (algo real y comprobado: en pruebas con
        // rutas reales grabadas, un tramo de ~50m sin conexión clara ya
        // basta para que lo parta), `NavigationRoutes` trata el resto como
        // "rutas alternativas" — con `showsAlternatives` a `true` (su valor
        // por defecto), el SDK las dibuja encima, del mismo ámbar que la
        // principal al forzar `alternativeRouteColors` arriba, y el
        // resultado es un segundo trazado sin relación con el primero
        // superpuesto en el mapa — la línea "hecha un lío" que parecía un
        // corte en la curva, cuando en realidad eran dos rutas distintas
        // dibujadas una encima de la otra. Aquí no tiene sentido mostrar
        // "alternativas": no es una elección real para quien sigue un
        // trazado grabado.
        brandedMapView.showsAlternatives = false

        // Banners propios en vez de los del SDK — la maquetación de los
        // suyos (constraints privadas) no deja meterles las etiquetas
        // "RESTANTE"/"LLEGADA" como pide el "modo navegación" de Claude
        // Design. Ver el doc de cada clase para el único hueco de fidelidad
        // real: la matrícula de carretera sale como texto normal, no como
        // recuadro tipo señal, y la flecha de giro es una aproximación
        // propia (SF Symbol rotado), no el glifo curvo exacto del SDK.
        let bottomBanner = RydrBottomBannerViewController()

        let navigationOptions = NavigationOptions(
            mapboxNavigation: navigationProvider.mapboxNavigation,
            voiceController: navigationProvider.routeVoiceController,
            eventsManager: navigationProvider.eventsManager(),
            // Solo el estilo noche: el resto de la app nunca cambia a un
            // tema claro (`overrideUserInterfaceStyle = .dark` en
            // `AppDelegate`), así que si aquí se dejaban los dos
            // (`RydrDayStyle` + `RydrNightStyle`) el SDK podía cambiar de
            // uno a otro solo según la hora del día — un salto de look
            // que no pasa en ninguna otra pantalla de Rydr.
            styles: [RydrNightStyle()],
            topBanner: RydrTopBannerViewController(
                speedLimitPublisher: navigation.locationMatching.map(\.speedLimit).eraseToAnyPublisher()),
            bottomBanner: bottomBanner,
            navigationMapView: brandedMapView
        )
        let navigationViewController = NavigationViewController(
            navigationRoutes: navigationRoutes,
            navigationOptions: navigationOptions
        )
        // Ya no hay una fase intermedia que encadenar (antes hacía falta el
        // delegado para saber "llegaste al inicio del trazado, arranca la
        // segunda guía") — se mantiene solo para el cierre disparado por el
        // propio SDK (p. ej. desde CarPlay), ver `dismissNavigation`.
        navigationViewController.delegate = self
        // El botón de cancelar del banner propio no pasa por el mecanismo
        // interno del SDK (`BottomBannerViewControllerDelegate`).
        bottomBanner.onCancelTapped = { [weak navigationViewController] in
            navigationViewController?.dismiss(animated: true)
        }
        navigationViewController.modalPresentationStyle = .fullScreen
        viewController.present(navigationViewController, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate (posición actual, one-shot)

// `@preconcurrency`: el protocolo no está aislado a `@MainActor` (lo llama
// el SDK de CoreLocation, que en la práctica siempre despacha en el hilo
// principal salvo que se configure una `delegateQueue` explícita, cosa que
// no hacemos), pero como esta clase entera sí lo está, el compilador no
// puede comprobarlo por su cuenta — sin esto, cruzar a código aislado a
// main actor desde una conformidad no aislada avisa ahora y en Swift 6
// sería un error.
extension RouteNavigationLauncher: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last?.coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - NavigationViewControllerDelegate

// Mismo motivo que en la conformidad de CLLocationManagerDelegate de
// arriba — el SDK de navegación llama a su delegado desde el hilo
// principal (es puramente de UI), pero el protocolo en sí no lleva la
// anotación `@MainActor`.
extension RouteNavigationLauncher: @preconcurrency NavigationViewControllerDelegate {
    /// Sin esto, un cierre disparado por el propio SDK (no por nuestro
    /// botón de cancelar) no hacía nada. El SDK decide si se cierra solo
    /// mirando si la llamada al delegado devolvió `nil`:
    /// `delegate?.navigationViewControllerDidDismiss(...)` es de tipo
    /// `Void?`, y en Swift eso da "no nil" en cuanto hay delegado — aunque
    /// el método no haga nada — así que por tener delegado el SDK asume
    /// "ya se encarga la app de cerrarlo" y se queda quieto.
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        navigationViewController.dismiss(animated: true)
    }
}
