import CoreLocation
import MapboxMaps
import UIKit

/// Pantalla "Registrar" — espejo de las pantallas `is.recIdle`/`is.recActive`
/// del prototipo de Claude Design ("modo en marcha"): en reposo, mapa con
/// GPS + tarjeta de moto + botón gigante "Empezar ruta"; grabando, cabecera
/// con cronómetro y cifras reales (km, velocidad media, desnivel) encima del
/// mapa con el trazado en vivo. Se abre a pantalla completa desde el botón
/// "Registrar" de `MainTabBarController`.
final class RegisterViewController: UIViewController {
    // Sin `private`: `RegisterViewController+UI.swift` (construcción de
    // vistas, sin estado de grabación) necesita leerlos/escribirlos —
    // `private` en Swift es por archivo, no por clase. Sigue sin ser
    // visible fuera del módulo, nada cambia de cara afuera.
    var mapView: MapView!
    private let locationManager = CLLocationManager()
    private let rideRepository = RideRepository()
    private let motorbikeRepository = MotorbikeRepository()

    private var currentRide: RideModel?
    // Tramos, distancia/desnivel acumulados, pausa y cronómetro — toda la
    // aritmética de grabar una ruta vive en esta clase (sin UIKit,
    // testable con XCTest), no aquí. Ver `Core/Recording/RideRecordingSession.swift`.
    private let recordingSession = RideRecordingSession()
    var polylineManager: PolylineAnnotationManager?
    private var lastCameraUpdate: Date?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var recordingTimer: Timer?
    private let liveActivity = RydrRideLiveActivityController()
    private let trackSyncManager = RideTrackSyncManager.shared
    private var foregroundObserver: NSObjectProtocol?

    private var bikes: [MotorbikeModel] = []
    private var selectedBike: MotorbikeModel?

    private var isRecording: Bool { currentRide != nil }

    // MARK: - Vistas compartidas entre los dos estados

    let idleContainer = UIView()
    let activeContainer = UIView()
    let idleMapWrapper = UIView()
    let activeMapWrapper = UIView()

    // Estado "en reposo".
    let gpsChipDot = UIView()
    let gpsChipLabel = UILabel()
    let bikeCardLabel = UILabel()
    let bikeCardCaption = UILabel()
    let startButton = UIButton(type: .system)

    // Estado "grabando".
    let recDot = UIView()
    let stateLabel = UILabel()
    let activeBikeLabel = UILabel()
    let timeLabel = UILabel()
    let kmValueLabel = UILabel()
    let speedValueLabel = UILabel()
    let elevationValueLabel = UILabel()
    let pauseButton = UIButton(type: .system)
    let pauseIcon = UIImageView()
    let pauseLabelView = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupMap()
        setupIdleContainer()
        setupActiveContainer()
        setupCloseButton()
        switchToIdle(animated: false)

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        Task {
            await loadBikes()
            // Después de cargar el garaje, no antes: para reconocer la moto
            // de la grabación pendiente hace falta tener ya `bikes` relleno.
            await offerToResumePendingRide()
        }

        // Cualquier punto que se quedara en cola local (de esta ruta o de
        // una anterior ya terminada) por falta de cobertura — sin esperar
        // a que quien graba vuelva a abrir "Registrar" a mano.
        trackSyncManager.resumeAllPending()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // `queue: .main` ya garantiza que esto se llama en el hilo
            // principal en tiempo de ejecución, pero el cierre en sí no
            // está aislado a `@MainActor` de cara al compilador — de ahí
            // el salto explícito, para poder llamar a `trackSyncManager`
            // (que sí lo está) sin aviso de Swift 6.
            Task { @MainActor in
                self?.trackSyncManager.resumeAllPending()
            }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    // MARK: - Pausa

    func updatePauseButton() {
        pauseIcon.image = UIImage(systemName: recordingSession.isPaused ? "play.fill" : "pause.fill")
        pauseLabelView.styleAsLabel(
            recordingSession.isPaused ? "Reanudar" : "Pausar", size: 15, color: AppTheme.text, tracking: 1.2)
    }

    private func updateRecordingStateLabel() {
        if recordingSession.isPaused {
            stateLabel.styleAsLabel(
                "En pausa", size: 12.5, medium: true, color: AppTheme.textSecondary(0.6), tracking: 1.4)
            recDot.backgroundColor = AppTheme.textSecondary(0.4)
            recDot.layer.removeAnimation(forKey: "pulse")
        } else {
            stateLabel.styleAsLabel("Grabando", size: 12.5, medium: true, color: AppTheme.primary, tracking: 1.4)
            recDot.backgroundColor = AppTheme.primary
            addPulseAnimation(to: recDot)
        }
    }

    @objc func onPauseTapped() {
        guard isRecording else { return }
        if recordingSession.isPaused {
            recordingSession.resume()
        } else {
            recordingSession.pause()
        }
        updatePauseButton()
        updateRecordingStateLabel()
    }

    @objc func onCloseTapped() {
        dismiss(animated: true)
    }

    // MARK: - Motos

    private func loadBikes() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        bikes = (try? await motorbikeRepository.getMotorbikes(userId: userId)) ?? []
        selectedBike = bikes.first(where: { $0.isCurrent }) ?? bikes.first
        updateBikeCard()
    }

    private func updateBikeCard() {
        if let bike = selectedBike {
            bikeCardLabel.text = bike.displayName
            bikeCardCaption.styleAsLabel("Moto actual · cambiar", size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        } else {
            bikeCardLabel.text = "Sin motos en el garaje"
            bikeCardCaption.styleAsLabel("Añade una moto para arrancar", size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        }
    }

    @objc func onChangeBikeTapped() {
        guard !bikes.isEmpty else {
            showAlert(title: "Sin motos", message: "Añade una moto desde tu perfil antes de iniciar una ruta.")
            return
        }
        Task {
            if let picked = await pickMotorbike(from: bikes) {
                selectedBike = picked
                updateBikeCard()
            }
        }
    }

    private func pickMotorbike(from bikes: [MotorbikeModel]) async -> MotorbikeModel? {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "¿Con qué moto sales?", message: nil, preferredStyle: .actionSheet)
            for bike in bikes {
                alert.addAction(UIAlertAction(title: bike.displayName, style: .default) { _ in
                    continuation.resume(returning: bike)
                })
            }
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            present(alert, animated: true)
        }
    }

    /// Espera la respuesta real del diálogo del sistema en vez de mirar
    /// `authorizationStatus` justo después de pedirlo (que en ese instante
    /// todavía tendría el valor de antes — la respuesta llega por
    /// delegado, de forma asíncrona). Solo espera de verdad cuando pedirlo
    /// puede realmente mostrar un diálogo nuevo (`.notDetermined`, o
    /// `.authorizedWhenInUse` — desde ahí iOS sí ofrece "ampliar a
    /// Siempre").
    ///
    /// Ojo: desde `.authorizedWhenInUse`, iOS solo enseña el diálogo de
    /// "ampliar a Siempre" LA PRIMERA VEZ que se pide en toda la vida de
    /// la instalación. Si el usuario ya respondió una vez (eligiendo
    /// "Mantener mientras se usa la app", sin subir a "Siempre"), cada
    /// pulsación posterior de "Empezar ruta" volvía a llamar a
    /// `requestAlwaysAuthorization()` sin que iOS enseñe ningún diálogo
    /// ni llame al delegado — la `continuation` se quedaba colgada para
    /// siempre y la pantalla parecía congelada. El timeout de abajo
    /// resuelve con el estado actual si el delegado no contesta a
    /// tiempo, cubriendo tanto este caso como cualquier otro en el que
    /// iOS decida no llamarlo.
    private func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        let current = locationManager.authorizationStatus
        guard current == .notDetermined || current == .authorizedWhenInUse else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, let pending = self.authorizationContinuation else { return }
                self.authorizationContinuation = nil
                pending.resume(returning: self.locationManager.authorizationStatus)
            }
        }
    }

    // MARK: - Grabar ruta

    @objc func onStartTapped() {
        Task { await startRideFlow() }
    }

    @objc func onFinishTapped() {
        Task { await finishRide() }
    }

    private func startRideFlow() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        guard !bikes.isEmpty else {
            showAlert(title: "Sin motos", message: "Añade una moto antes de iniciar una ruta.")
            return
        }
        var bike = selectedBike
        if bike == nil { bike = await pickMotorbike(from: bikes) }
        guard let bike else { return }
        selectedBike = bike

        // Se sigue pidiendo "siempre" (si ya la tiene concedida, esto no
        // enseña ningún diálogo) para aprovechar grabación en segundo
        // plano cuando esté disponible, pero ya no bloquea ni avisa si
        // falta — se empieza a grabar igual con lo que haya. Sin
        // "Siempre", iOS puede pausar las actualizaciones al bloquear el
        // móvil (el trazado puede salir con huecos), pero es la decisión
        // que se ha pedido: no interrumpir con el aviso.
        let authorization = await requestAlwaysAuthorization()
        if authorization == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        }

        do {
            let ride = try await rideRepository.startRide(riderId: userId, motorbikeId: bike.id)
            currentRide = ride
            recordingSession.start()
            UserDefaults.standard.set(ride.id, forKey: Self.pendingRideIdKey)
            activeBikeLabel.styleAsLabel(bike.displayName, size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)
            updateRecordingStateLabel()
            updatePauseButton()
            switchToActive()
            startTimer()
            liveActivity.start(motorbikeName: bike.displayName)
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }

    // MARK: - Recuperar una grabación a medias

    // Solo se guarda el id — el resto del estado (moto, puntos ya
    // grabados, hora de inicio) se reconstruye pidiéndoselo de nuevo al
    // backend, que es la fuente de verdad real mientras se está grabando
    // (cada punto ya se manda al momento, no se acumulan sin guardar).
    private static let pendingRideIdKey = "com.rydr.pendingRideId"

    private func offerToResumePendingRide() async {
        guard !isRecording, let pendingId = UserDefaults.standard.object(forKey: Self.pendingRideIdKey) as? Int
        else { return }
        guard let ride = try? await rideRepository.getRide(id: pendingId), ride.isActive else {
            // Ya no existe, o ya se cerró desde otro sitio — nada que
            // ofrecer, y sin dejar el aviso pegado para la próxima vez.
            UserDefaults.standard.removeObject(forKey: Self.pendingRideIdKey)
            return
        }

        let alert = UIAlertController(
            title: "Ruta sin terminar",
            message: "Tienes una grabación en curso desde \(Self.timeFormatter.string(from: ride.startedAt)) "
                + "que se quedó a medias (\(ride.trackPoints.count) puntos). ¿Continuar o descartarla?",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Descartar", style: .destructive) { [weak self] _ in
            Task { await self?.discardPendingRide(ride) }
        })
        alert.addAction(UIAlertAction(title: "Continuar", style: .default) { [weak self] _ in
            self?.resumeRide(ride)
        })
        present(alert, animated: true)
    }

    private func discardPendingRide(_ ride: RideModel) async {
        // "Descartar" aquí es solo dejar de considerarla activa — a
        // diferencia del descarte automático de `finishRide` (menos de
        // `minimumPointsToKeep` puntos), esta puede tener un trazado real
        // que alguien quiera conservar desde "Mis rides" más tarde, así
        // que se finaliza, no se borra.
        _ = try? await rideRepository.finishRide(rideId: ride.id)
        UserDefaults.standard.removeObject(forKey: Self.pendingRideIdKey)
    }

    private func resumeRide(_ ride: RideModel) {
        if let bike = bikes.first(where: { $0.id == ride.motorbikeId }) {
            selectedBike = bike
            activeBikeLabel.styleAsLabel(bike.displayName, size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)
        } else {
            // No debería pasar (la moto usada ya existía cuando se arrancó
            // la grabación), pero si pasa no se pierde la ruta por eso —
            // se sigue grabando igual, solo sin mostrar de qué moto es.
            activeBikeLabel.text = nil
        }

        // El backend puede no saber nada de la cola final del todo si el
        // cierre a medias coincidió con quedarse sin cobertura — se suman
        // los puntos que `RideTrackSyncManager` todavía tenga pendientes
        // de mandar para este ride, para que ni el trazado ni las cifras
        // se vean con un hueco al final por algo que en realidad está a
        // salvo en el propio móvil.
        let backendPoints = ride.trackPoints.map {
            RideRecordingSession.RestorePoint(
                coordinate: $0.coordinate, altitude: $0.altitude, isSegmentStart: $0.isSegmentStart, timestamp: $0.timestamp)
        }
        let pendingPoints = trackSyncManager.pendingPoints(forRide: ride.id).map {
            RideRecordingSession.RestorePoint(
                coordinate: $0.coordinate, altitude: $0.altitude, isSegmentStart: $0.isSegmentStart, timestamp: $0.timestamp)
        }

        currentRide = ride
        recordingSession.restore(from: backendPoints + pendingPoints, rideStartDate: ride.startedAt)

        updateRecordingStateLabel()
        updatePauseButton()
        switchToActive()
        redrawTrack()
        startTimer()
        liveActivity.start(motorbikeName: selectedBike?.displayName ?? "")
        trackSyncManager.attemptDrain(rideId: ride.id)
    }

    /// Por debajo de este número de puntos, el ride se descarta en vez de
    /// guardarse — no hay suficiente trazado como para ser una ruta real.
    private static let minimumPointsToKeep = 10

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func finishRide() async {
        guard let ride = currentRide else { return }
        do {
            _ = try await rideRepository.finishRide(rideId: ride.id)
            // Instantánea de lo que hay en memoria — completo siempre,
            // pase lo que pase con la sincronización de la cola local
            // (ver `PublishSource.freshlyRecorded` en
            // `PublishRouteViewController`) — a diferencia de
            // `ride.track_points` en el backend, que en este mismo
            // instante todavía podría no tener los últimos puntos si no
            // ha habido cobertura hasta ahora mismo.
            let pointCount = recordingSession.pointCount
            let publishSegments = recordingSession.trackSegments
            let distanceKm = (recordingSession.totalDistanceMeters / 1000 * 100).rounded() / 100
            // `currentElapsed()`, no el reloj de pared en crudo: si se
            // termina la ruta estando pausada (o hubo alguna pausa antes),
            // ese rato no debe contarse como duración recorrida.
            let durationMinutes = max(1, Int(recordingSession.currentElapsed() / 60))
            currentRide = nil
            UserDefaults.standard.removeObject(forKey: Self.pendingRideIdKey)
            stopTimer()
            liveActivity.end()
            switchToIdle(animated: true)
            // Ya no hace falta que el sistema mantenga la app viva en
            // segundo plano por localización.
            locationManager.allowsBackgroundLocationUpdates = false
            mapView.camera.ease(
                to: CameraOptions(center: locationManager.location?.coordinate, zoom: 15, bearing: 0),
                duration: 0.4)
            // Último intento inmediato por si hay cobertura justo ahora —
            // si no, sigue en cola y se reintentará sola (temporizador de
            // la próxima grabación, o al reabrir la app/volver a primer
            // plano vía `resumeAllPending`).
            trackSyncManager.attemptDrain(rideId: ride.id)

            if pointCount < Self.minimumPointsToKeep {
                // Se finaliza igual (para liberar el estado "activo" en el
                // backend) pero no se conserva: muy pocos puntos como para
                // ser una ruta real.
                try? await rideRepository.deleteRide(id: ride.id)
                trackSyncManager.discard(rideId: ride.id)
                showAlert(
                    title: "Ruta descartada",
                    message: "Solo se grabaron \(pointCount) puntos (mínimo \(Self.minimumPointsToKeep)). No se ha guardado.")
            } else {
                // PublishRouteViewController se cierra a sí mismo al
                // publicar con éxito; aquí no hace falta ningún efecto
                // extra — el usuario se queda en el mapa y cierra con la X
                // cuando quiera.
                let publish = PublishRouteViewController(
                    source: .freshlyRecorded(
                        segments: publishSegments, distanceKm: distanceKm, durationMinutes: durationMinutes),
                    pointCount: pointCount, onPublished: {})
                present(UINavigationController(rootViewController: publish), animated: true)
            }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateActiveStats()
        }
        updateActiveStats()
    }

    /// Redibuja el trazado entero — tanto al añadir un punto en vivo como
    /// al reconstruir de golpe el historial de una grabación reanudada.
    /// Un `PolylineAnnotation` por tramo (ver `trackSegments`): así el
    /// hueco de una pausa no sale dibujado como si fuera carretera
    /// recorrida.
    private func redrawTrack() {
        polylineManager?.annotations = recordingSession.trackSegments.filter { $0.count >= 2 }.map { segment in
            var polyline = PolylineAnnotation(lineCoordinates: segment)
            polyline.lineColor = StyleColor(AppTheme.primary)
            polyline.lineWidth = 7
            // Borde oscuro alrededor del trazado ámbar — sin él, la línea
            // se mezcla con el fondo claro del estilo `outdoors` en zonas
            // de asfalto/tierra parecidas en tono. Con el borde se recorta
            // igual de bien sobre calles claras que oscuras.
            polyline.lineBorderColor = StyleColor(AppTheme.bg0)
            polyline.lineBorderWidth = 1.6
            return polyline
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateActiveStats() {
        guard recordingSession.rideStartDate != nil else { return }
        // `currentElapsed()`, no el reloj de pared: mientras `isPaused`
        // se queda congelado en vez de seguir sumando, y al terminar una
        // pausa no arrastra ese rato ni en el cronómetro ni en la
        // velocidad media.
        let elapsed = recordingSession.currentElapsed()
        let elapsedSeconds = Int(elapsed)
        timeLabel.text = String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)

        let km = recordingSession.totalDistanceMeters / 1000
        kmValueLabel.text = String(format: "%.1f", km)
        elevationValueLabel.text = String(format: "%.0f", recordingSession.totalElevationGainMeters)
        let hours = elapsed / 3600
        let speedKmh = hours > 0 ? km / hours : 0
        speedValueLabel.text = String(format: "%.0f", speedKmh)

        // La Live Activity se actualiza cada 5s, no cada segundo como el
        // resto de esta pantalla — tiene un presupuesto limitado de
        // actualizaciones por hora, y nadie necesita el cronómetro de la
        // pantalla de bloqueo al segundo exacto.
        if elapsedSeconds % 5 == 0 {
            liveActivity.update(elapsedSeconds: elapsedSeconds, km: km, speedKmh: speedKmh)
        }

        // Reintento periódico de la cola local (sin cobertura, los puntos
        // se han seguido guardando igual — ver `RideTrackSyncManager`) —
        // cada 15s, no en cada punto: si sigue sin haber señal no tiene
        // sentido intentarlo cada segundo.
        if elapsedSeconds % 15 == 0, let rideId = currentRide?.id {
            trackSyncManager.attemptDrain(rideId: rideId)
        }
    }

}

// MARK: - CLLocationManagerDelegate

extension RegisterViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate

        if location.horizontalAccuracy >= 0 {
            gpsChipDot.backgroundColor = AppTheme.accentTeal
            gpsChipLabel.styleAsLabel(
                "GPS listo · ±\(Int(location.horizontalAccuracy))m", size: 12, medium: true,
                color: AppTheme.textSecondary(0.75), tracking: 0.7)
        }

        let now = Date()
        if lastCameraUpdate == nil || now.timeIntervalSince(lastCameraUpdate!) > 0.3 {
            lastCameraUpdate = now
            mapView.camera.ease(
                to: CameraOptions(center: coordinate, zoom: isRecording ? 17 : 15), duration: 0.3)
        }

        guard isRecording, let ride = currentRide else { return }
        // `record(...)` devuelve `nil` sin tocar nada si está pausado —
        // ni trazado, ni cifras, ni cola de sync (solo el chip de GPS y
        // la cámara de arriba siguen igual que en reposo). Ver
        // `RideRecordingSession.record(coordinate:altitude:)`.
        guard let result = recordingSession.record(coordinate: coordinate, altitude: location.altitude) else { return }
        redrawTrack()

        // Antes se mandaba directo a la red con un `try?` que se tragaba
        // el error en silencio — sin cobertura (el caso de uso central de
        // esta app: carretera de montaña), el punto se perdía para
        // siempre. Ahora se encola primero — nunca falla, nunca espera a
        // la red — y de ahí se intenta mandar cada 15s desde
        // `updateActiveStats`, no en cada punto: intentarlo cada 1-3s
        // mientras no hay cobertura no serviría de nada, solo peticiones
        // fallidas de más. Ver `RideTrackSyncManager`.
        trackSyncManager.enqueue(rideId: ride.id, point: PendingTrackPoint(
            latitude: coordinate.latitude, longitude: coordinate.longitude,
            altitude: location.altitude, speed: location.speed >= 0 ? location.speed * 3.6 : nil,
            timestamp: location.timestamp, isSegmentStart: result.isSegmentStart))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
    }
}
