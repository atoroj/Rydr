import CoreLocation
import MapboxMaps
import UIKit

/// Pantalla "Registrar": se abre a pantalla completa desde el botón
/// circular de `MainTabBarController`. Mapa a pantalla completa +
/// Iniciar/Pausar-Reanudar/Finalizar. Espejo de
/// lib/features/register/presentation/register_screen.dart.
final class RegisterViewController: UIViewController {
    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private let rideRepository = RideRepository()
    private let motorbikeRepository = MotorbikeRepository()

    private var currentRide: RideModel?
    private var trackCoordinates: [CLLocationCoordinate2D] = []
    private var polylineManager: PolylineAnnotationManager?
    private var lastCameraUpdate: Date?
    private var rideStartDate: Date?
    private var recordingTimer: Timer?
    private var isPaused = false

    private let hudCard = UIView()
    private let timeLabel = UILabel()
    private let pointsLabel = UILabel()
    private let stateLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let finishButton = UIButton(type: .system)

    private var isRecording: Bool { currentRide != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupMap()
        setupHUD()
        setupCloseButton()
        setupControls()
        setupCenterButton()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - UI

    private func setupMap() {
        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.location.options = LocationOptions(
            puckType: .puck2D(), puckBearing: .heading, puckBearingEnabled: true)
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        polylineManager = mapView.annotations.makePolylineAnnotationManager()
    }

    private func setupCloseButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupHUD() {
        hudCard.backgroundColor = .systemBackground
        hudCard.layer.cornerRadius = 12
        hudCard.layer.shadowColor = UIColor.black.cgColor
        hudCard.layer.shadowOpacity = 0.15
        hudCard.layer.shadowRadius = 6
        hudCard.layer.shadowOffset = CGSize(width: 0, height: 2)
        hudCard.isHidden = true
        hudCard.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .boldSystemFont(ofSize: 16)
        timeLabel.textAlignment = .center
        pointsLabel.font = .boldSystemFont(ofSize: 16)
        pointsLabel.textAlignment = .center
        stateLabel.font = .boldSystemFont(ofSize: 16)
        stateLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            labeled(timeLabel, caption: "Tiempo"), labeled(pointsLabel, caption: "Puntos"),
            labeled(stateLabel, caption: "Estado"),
        ])
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        hudCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: hudCard.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -16),
        ])

        view.addSubview(hudCard)
        NSLayoutConstraint.activate([
            hudCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            hudCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 64),
            hudCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func labeled(_ valueLabel: UILabel, caption: String) -> UIView {
        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 11)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    /// Botones grandes (`AppTheme.gloveButtonHeight`) pensados para pulsarse
    /// con guantes: "Iniciar ruta" en reposo; "Pausar/Reanudar" +
    /// "Finalizar" lado a lado mientras se graba.
    private func setupControls() {
        configure(startButton, title: "Iniciar ruta", background: AppTheme.primary)
        startButton.addTarget(self, action: #selector(onStartTapped), for: .touchUpInside)

        configure(pauseButton, title: "Pausar", background: .systemGray)
        pauseButton.addTarget(self, action: #selector(onPauseTapped), for: .touchUpInside)
        pauseButton.isHidden = true

        configure(finishButton, title: "Finalizar", background: .systemRed)
        finishButton.addTarget(self, action: #selector(onFinishTapped), for: .touchUpInside)
        finishButton.isHidden = true

        let recordingStack = UIStackView(arrangedSubviews: [pauseButton, finishButton])
        recordingStack.axis = .horizontal
        recordingStack.spacing = 12
        recordingStack.distribution = .fillEqually

        [startButton, recordingStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(startButton)
        view.addSubview(recordingStack)

        NSLayoutConstraint.activate([
            startButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            startButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight),

            recordingStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            recordingStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            recordingStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pauseButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight),
        ])
    }

    private func configure(_ button: UIButton, title: String, background: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 17)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = background
        button.layer.cornerRadius = AppTheme.gloveButtonHeight / 2
    }

    private func setupCenterButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "location.fill"), for: .normal)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onCenterTapped), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -16),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func onCenterTapped() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        mapView.camera.ease(to: CameraOptions(center: coordinate, zoom: 15), duration: 0.4)
    }

    @objc private func onCloseTapped() {
        dismiss(animated: true)
    }

    // MARK: - Grabar ruta

    @objc private func onStartTapped() {
        Task { await startRideFlow() }
    }

    @objc private func onPauseTapped() {
        isPaused.toggle()
        pauseButton.setTitle(isPaused ? "Reanudar" : "Pausar", for: .normal)
        updateHUD()
    }

    @objc private func onFinishTapped() {
        Task { await finishRide() }
    }

    private func startRideFlow() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        do {
            let bikes = try await motorbikeRepository.getMotorbikes(userId: userId)
            guard !bikes.isEmpty else {
                showAlert(title: "Sin motos", message: "Añade una moto antes de iniciar una ruta.")
                return
            }
            guard let bike = await pickMotorbike(from: bikes) else { return }

            // Pide "siempre" antes de arrancar: sin este permiso el sistema
            // mata las actualizaciones de posición en cuanto la app pasa a
            // segundo plano y la grabación se corta a medias.
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false

            let ride = try await rideRepository.startRide(riderId: userId, motorbikeId: bike.id)
            currentRide = ride
            trackCoordinates = []
            rideStartDate = Date()
            isPaused = false
            hudCard.isHidden = false
            startButton.isHidden = true
            pauseButton.isHidden = false
            pauseButton.setTitle("Pausar", for: .normal)
            finishButton.isHidden = false
            startTimer()
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
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

    /// Por debajo de este número de puntos, el ride se descarta en vez de
    /// guardarse — no hay suficiente trazado como para ser una ruta real.
    private static let minimumPointsToKeep = 10

    private func finishRide() async {
        guard let ride = currentRide else { return }
        do {
            _ = try await rideRepository.finishRide(rideId: ride.id)
            let pointCount = trackCoordinates.count
            currentRide = nil
            isPaused = false
            stopTimer()
            hudCard.isHidden = true
            startButton.isHidden = false
            pauseButton.isHidden = true
            finishButton.isHidden = true
            // Ya no hace falta que el sistema mantenga la app viva en
            // segundo plano por localización.
            locationManager.allowsBackgroundLocationUpdates = false
            mapView.camera.ease(
                to: CameraOptions(center: locationManager.location?.coordinate, zoom: 15, bearing: 0),
                duration: 0.4)

            if pointCount < Self.minimumPointsToKeep {
                // Se finaliza igual (para liberar el estado "activo" en el
                // backend) pero no se conserva: muy pocos puntos como para
                // ser una ruta real.
                try? await rideRepository.deleteRide(id: ride.id)
                showAlert(
                    title: "Ruta descartada",
                    message: "Solo se grabaron \(pointCount) puntos (mínimo \(Self.minimumPointsToKeep)). No se ha guardado.")
            } else {
                // PublishRouteViewController se cierra a sí mismo al
                // publicar con éxito; aquí no hace falta ningún efecto
                // extra — el usuario se queda en el mapa y cierra con la X
                // cuando quiera.
                let publish = PublishRouteViewController(rideId: ride.id, pointCount: pointCount) {}
                present(UINavigationController(rootViewController: publish), animated: true)
            }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateHUD()
        }
        updateHUD()
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateHUD() {
        guard let start = rideStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        timeLabel.text = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
        pointsLabel.text = "\(trackCoordinates.count)"
        stateLabel.text = isPaused ? "Pausado" : "Grabando"
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension RegisterViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate

        let now = Date()
        if lastCameraUpdate == nil || now.timeIntervalSince(lastCameraUpdate!) > 0.3 {
            lastCameraUpdate = now
            mapView.camera.ease(
                to: CameraOptions(center: coordinate, zoom: (isRecording && !isPaused) ? 17 : 15), duration: 0.3)
        }

        // En pausa seguimos centrando el mapa en la posición actual, pero
        // no se añaden puntos al trazado ni se manda nada al backend.
        guard isRecording, !isPaused, let ride = currentRide else { return }
        trackCoordinates.append(coordinate)

        if trackCoordinates.count >= 2 {
            var polyline = PolylineAnnotation(lineCoordinates: trackCoordinates)
            polyline.lineColor = StyleColor(AppTheme.primary)
            polyline.lineWidth = 4
            polylineManager?.annotations = [polyline]
        }

        Task {
            try? await rideRepository.addTrackPoint(
                rideId: ride.id, latitude: coordinate.latitude, longitude: coordinate.longitude,
                altitude: location.altitude, speed: location.speed >= 0 ? location.speed * 3.6 : nil,
                timestamp: location.timestamp)
        }
    }
}
