import CoreLocation
import MapboxMaps
import UIKit

/// Vista previa antes de arrancar la guía turn-by-turn — al estilo Google
/// Maps: primero se ve el recorrido completo (tu posición → inicio del
/// trazado → final), con distancia y tiempo estimado, y solo al pulsar
/// "Iniciar" arranca la navegación de verdad. Sustituye lanzar la guía
/// directamente al pulsar "Seguir ruta en la app" en `RouteDetailViewController`.
final class RoutePreviewViewController: UIViewController {
    private let route: RouteModel
    private var mapView: MapView!
    private var polylineManager: PolylineAnnotationManager?

    private let directionControl = UISegmentedControl(items: ["Desde el principio", "Desde el final"])
    private let statsLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    /// Punto de partida elegido para calcular la vista previa y arrancar la
    /// guía — el primer punto grabado del trazado, o el último si se elige
    /// "Desde el final" (para hacer la ruta al revés).
    private var reversed: Bool { directionControl.selectedSegmentIndex == 1 }
    private var startingPoint: CLLocationCoordinate2D? { reversed ? route.path.last : route.path.first }

    init(route: RouteModel) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupMap()
        setupCloseButton()
        setupBottomCard()
        Task { await loadPreview() }
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

    private func setupBottomCard() {
        let card = UIView()
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.3
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: -2)
        card.translatesAutoresizingMaskIntoConstraints = false

        // Solo tiene sentido ofrecerlo si hay trazado real entre dos
        // extremos distintos — con menos de 2 puntos no hay "principio" ni
        // "final" que elegir.
        directionControl.isHidden = route.path.count < 2
        directionControl.selectedSegmentIndex = 0
        directionControl.backgroundColor = AppTheme.bg2
        directionControl.setTitleTextAttributes([.foregroundColor: AppTheme.textSecondary(0.6)], for: .normal)
        directionControl.setTitleTextAttributes([.foregroundColor: AppTheme.text], for: .selected)
        directionControl.addTarget(self, action: #selector(onDirectionChanged), for: .valueChanged)

        statsLabel.text = "Calculando ruta…"
        statsLabel.font = AppFont.body(14)
        statsLabel.textColor = AppTheme.textSecondary(0.6)
        statsLabel.textAlignment = .center
        statsLabel.numberOfLines = 2

        startButton.setTitle("Iniciar", for: .normal)
        startButton.titleLabel?.font = AppFont.body(17, .bold)
        startButton.setTitleColor(AppTheme.bg0, for: .normal)
        startButton.backgroundColor = AppTheme.primary
        startButton.layer.cornerRadius = AppTheme.gloveButtonHeight / 2
        startButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        startButton.addTarget(self, action: #selector(onStartTapped), for: .touchUpInside)

        statusLabel.font = AppFont.body(13)
        statusLabel.textColor = AppTheme.textSecondary(0.5)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [directionControl, statsLabel, startButton, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Cargar la vista previa

    private func loadPreview() async {
        var polylines: [PolylineAnnotation] = []
        var boundsCoordinates = route.path

        if route.path.count >= 2 {
            var exactRoute = PolylineAnnotation(lineCoordinates: route.path)
            exactRoute.lineColor = StyleColor(AppTheme.primary)
            exactRoute.lineWidth = 4
            polylines.append(exactRoute)
        }

        var statsText = "\(route.distanceKm) km · \(route.durationMinutes) min"

        if let startingPoint,
           let approach = await RouteNavigationLauncher.shared.previewApproach(to: startingPoint)
        {
            var approachLine = PolylineAnnotation(lineCoordinates: approach.coordinates)
            approachLine.lineColor = StyleColor(AppTheme.accentTeal)
            approachLine.lineWidth = 4
            polylines.append(approachLine)
            boundsCoordinates += approach.coordinates

            let approachKm = approach.distanceMeters / 1000
            let approachMinutes = max(1, Int((approach.durationSeconds / 60).rounded()))
            statsText = "Hasta el inicio: \(String(format: "%.1f", approachKm)) km · \(approachMinutes) min\n"
                + "Ruta: " + statsText
        }

        polylineManager?.annotations = polylines
        statsLabel.text = statsText

        if !boundsCoordinates.isEmpty,
           let camera = try? mapView.mapboxMap.camera(
               for: boundsCoordinates, camera: CameraOptions(),
               coordinatesPadding: UIEdgeInsets(top: 60, left: 40, bottom: 180, right: 40),
               maxZoom: nil, offset: nil)
        {
            mapView.mapboxMap.setCamera(to: camera)
        }
    }

    // MARK: - Acciones

    @objc private func onCloseTapped() {
        dismiss(animated: true)
    }

    @objc private func onDirectionChanged() {
        statsLabel.text = "Calculando ruta…"
        Task { await loadPreview() }
    }

    @objc private func onStartTapped() {
        startButton.isEnabled = false
        statusLabel.text = "Calculando ruta…"

        Task {
            do {
                try await RouteNavigationLauncher.shared.start(route: route, reversed: reversed, presentingFrom: self)
                statusLabel.text = nil
                try? await RouteRepository().markAsRidden(routeId: route.id)
            } catch {
                statusLabel.text = "Error: \(error.localizedDescription)"
            }
            startButton.isEnabled = true
        }
    }
}
