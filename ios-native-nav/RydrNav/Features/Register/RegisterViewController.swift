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
    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private let rideRepository = RideRepository()
    private let motorbikeRepository = MotorbikeRepository()

    private var currentRide: RideModel?
    private var trackCoordinates: [CLLocationCoordinate2D] = []
    private var polylineManager: PolylineAnnotationManager?
    private var lastCameraUpdate: Date?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var rideStartDate: Date?
    private var recordingTimer: Timer?
    private let liveActivity = RydrRideLiveActivityController()
    private let trackSyncManager = RideTrackSyncManager.shared
    private var foregroundObserver: NSObjectProtocol?

    // Cifras reales de la grabación en curso — nada de datos de relleno:
    // la distancia sale de sumar la distancia entre puntos consecutivos,
    // el desnivel de sumar solo los tramos en que la altitud sube (>1m,
    // para no acumular el ruido normal del GPS/barómetro), y la velocidad
    // media de distancia ÷ tiempo transcurrido.
    private var totalDistanceMeters: CLLocationDistance = 0
    private var totalElevationGainMeters: Double = 0
    private var lastAltitude: Double?

    private var bikes: [MotorbikeModel] = []
    private var selectedBike: MotorbikeModel?

    private var isRecording: Bool { currentRide != nil }

    // MARK: - Vistas compartidas entre los dos estados

    private let idleContainer = UIView()
    private let activeContainer = UIView()
    private let idleMapWrapper = UIView()
    private let activeMapWrapper = UIView()

    // Estado "en reposo".
    private let gpsChipDot = UIView()
    private let gpsChipLabel = UILabel()
    private let bikeCardLabel = UILabel()
    private let bikeCardCaption = UILabel()
    private let startButton = UIButton(type: .system)

    // Estado "grabando".
    private let recDot = UIView()
    private let stateLabel = UILabel()
    private let activeBikeLabel = UILabel()
    private let timeLabel = UILabel()
    private let kmValueLabel = UILabel()
    private let speedValueLabel = UILabel()
    private let elevationValueLabel = UILabel()

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

    // MARK: - Mapa compartido

    private func setupMap() {
        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.location.options = LocationOptions(
            puckType: .puck2D(Self.brandedPuck), puckBearing: .heading, puckBearingEnabled: true)
        polylineManager = mapView.annotations.makePolylineAnnotationManager()
        polylineManager?.lineCap = .round
        polylineManager?.lineJoin = .round
    }

    /// Punto de posición en el ámbar de marca (con anillo de precisión y
    /// pulso a juego) en vez del azul por defecto del SDK — mismo espíritu
    /// que `RydrNavigationStyle`, aplicado aquí también.
    private static let brandedPuck: Puck2DConfiguration = {
        var puck = Puck2DConfiguration(topImage: dotImage())
        puck.pulsing = .init(color: AppTheme.primary, radius: .accuracy)
        puck.showsAccuracyRing = true
        puck.accuracyRingColor = AppTheme.primary.withAlphaComponent(0.12)
        puck.accuracyRingBorderColor = AppTheme.primary.withAlphaComponent(0.3)
        return puck
    }()

    private static func dotImage() -> UIImage {
        let size = CGSize(width: 22, height: 22)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            AppTheme.bg0.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            AppTheme.primary.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
    }

    /// Traslada el mapa compartido al contenedor del estado que toca
    /// mostrar — así la cámara y el trazado dibujado no se reinician al
    /// pasar de reposo a grabando.
    private func moveMapView(to wrapper: UIView) {
        guard mapView.superview !== wrapper else { return }
        mapView.removeFromSuperview()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
    }

    /// Botón de cerrar en cristal de verdad (Liquid Glass en iOS 26,
    /// esmerilado normal antes) en vez del círculo negro semitransparente
    /// de antes — aquí sí tiene sentido notarse, porque detrás siempre hay
    /// mapa en movimiento, a diferencia de la barra inferior (fondo plano)
    /// donde lo probamos primero.
    private func setupCloseButton() {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        let glass = UIVisualEffectView(effect: effect)
        glass.layer.cornerRadius = 18
        glass.clipsToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
        glass.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: glass.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: glass.centerYAnchor),
        ])

        view.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            glass.widthAnchor.constraint(equalToConstant: 36),
            glass.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Estado "en reposo" (is.recIdle)

    private func setupIdleContainer() {
        idleContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(idleContainer)
        NSLayoutConstraint.activate([
            idleContainer.topAnchor.constraint(equalTo: view.topAnchor),
            idleContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            idleContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            idleContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        idleMapWrapper.translatesAutoresizingMaskIntoConstraints = false
        idleMapWrapper.clipsToBounds = true

        gpsChipDot.backgroundColor = AppTheme.textSecondary(0.3)
        gpsChipDot.layer.cornerRadius = 3.5
        gpsChipDot.translatesAutoresizingMaskIntoConstraints = false
        gpsChipDot.widthAnchor.constraint(equalToConstant: 7).isActive = true
        gpsChipDot.heightAnchor.constraint(equalToConstant: 7).isActive = true

        gpsChipLabel.styleAsLabel("Buscando GPS…", size: 12, medium: true, color: AppTheme.textSecondary(0.75), tracking: 0.7)

        let gpsChip = UIStackView(arrangedSubviews: [gpsChipDot, gpsChipLabel])
        gpsChip.axis = .horizontal
        gpsChip.spacing = 9
        gpsChip.alignment = .center
        gpsChip.isLayoutMarginsRelativeArrangement = true
        gpsChip.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
        gpsChip.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        gpsChip.layer.cornerRadius = 11
        gpsChip.clipsToBounds = true
        gpsChip.translatesAutoresizingMaskIntoConstraints = false

        idleMapWrapper.addSubview(gpsChip)
        NSLayoutConstraint.activate([
            gpsChip.topAnchor.constraint(equalTo: idleMapWrapper.safeAreaLayoutGuide.topAnchor, constant: 8),
            gpsChip.leadingAnchor.constraint(equalTo: idleMapWrapper.leadingAnchor, constant: 54),
            gpsChip.trailingAnchor.constraint(lessThanOrEqualTo: idleMapWrapper.trailingAnchor, constant: -14),
        ])

        let bikeCard = buildBikeSelectorCard()

        startButton.backgroundColor = AppTheme.primary
        startButton.layer.cornerRadius = 22
        startButton.layer.shadowColor = AppTheme.primary.cgColor
        startButton.layer.shadowOpacity = 0.35
        startButton.layer.shadowRadius = 14
        startButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        startButton.heightAnchor.constraint(equalToConstant: 88).isActive = true
        startButton.addTarget(self, action: #selector(onStartTapped), for: .touchUpInside)

        let startTitle = UILabel()
        startTitle.styleAsLabel("Empezar ruta", size: 24, color: AppTheme.bg0, tracking: 2)
        let startSubtitle = UILabel()
        startSubtitle.styleAsLabel("se graba en segundo plano", size: 11.5, medium: true, color: AppTheme.bg0.withAlphaComponent(0.6), tracking: 0.8)
        let startTextStack = UIStackView(arrangedSubviews: [startTitle, startSubtitle])
        startTextStack.axis = .vertical
        startTextStack.spacing = 2
        startTextStack.alignment = .center
        startTextStack.isUserInteractionEnabled = false
        startTextStack.translatesAutoresizingMaskIntoConstraints = false
        startButton.addSubview(startTextStack)
        NSLayoutConstraint.activate([
            startTextStack.centerXAnchor.constraint(equalTo: startButton.centerXAnchor),
            startTextStack.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
        ])

        let contentStack = UIStackView(arrangedSubviews: [bikeCard, startButton])
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        idleContainer.addSubview(idleMapWrapper)
        idleContainer.addSubview(contentStack)
        NSLayoutConstraint.activate([
            idleMapWrapper.topAnchor.constraint(equalTo: idleContainer.topAnchor),
            idleMapWrapper.leadingAnchor.constraint(equalTo: idleContainer.leadingAnchor),
            idleMapWrapper.trailingAnchor.constraint(equalTo: idleContainer.trailingAnchor),
            // Ya no una altura fija — el mapa ocupa todo lo que sobra por
            // encima de la tarjeta de moto + botón de empezar (que ahora,
            // sin los dos botones secundarios que había debajo, también
            // dejan más hueco libre).
            idleMapWrapper.bottomAnchor.constraint(equalTo: contentStack.topAnchor, constant: -16),

            contentStack.leadingAnchor.constraint(equalTo: idleContainer.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: idleContainer.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(
                equalTo: idleContainer.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func buildBikeSelectorCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onChangeBikeTapped)))

        let swatch = UIView()
        swatch.backgroundColor = AppTheme.bg3
        swatch.layer.cornerRadius = 8
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: 44).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: 34).isActive = true

        bikeCardLabel.font = AppFont.body(14.5, .semibold)
        bikeCardLabel.textColor = AppTheme.text
        bikeCardLabel.text = "Cargando tus motos…"

        bikeCardCaption.styleAsLabel("Moto actual · cambiar", size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [bikeCardLabel, bikeCardCaption])
        textStack.axis = .vertical
        textStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppTheme.textSecondary(0.5)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let row = UIStackView(arrangedSubviews: [swatch, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 11
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
        ])
        return card
    }

    // MARK: - Estado "grabando" (is.recActive)

    private func setupActiveContainer() {
        activeContainer.translatesAutoresizingMaskIntoConstraints = false
        activeContainer.backgroundColor = AppTheme.bg1
        view.addSubview(activeContainer)
        NSLayoutConstraint.activate([
            activeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            activeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            activeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            activeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        recDot.backgroundColor = AppTheme.primary
        recDot.layer.cornerRadius = 4.5
        recDot.translatesAutoresizingMaskIntoConstraints = false
        recDot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        recDot.heightAnchor.constraint(equalToConstant: 9).isActive = true
        addPulseAnimation(to: recDot)

        stateLabel.styleAsLabel("Grabando", size: 12.5, medium: true, color: AppTheme.primary, tracking: 1.4)
        activeBikeLabel.styleAsLabel(size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)

        let headerRow = UIStackView(arrangedSubviews: [recDot, stateLabel, UIView(), activeBikeLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 9
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        // Más pequeño que antes (era 70pt a toda plana, empujando el mapa
        // hacia abajo) — ahora vive dentro de una tarjeta flotante sobre el
        // mapa a pantalla completa, así que no necesita tanto peso visual;
        // el trazado en vivo es el protagonista, no el cronómetro.
        timeLabel.font = AppFont.data(46)
        timeLabel.textColor = AppTheme.text
        timeLabel.text = "00:00"

        let timeCaption = UILabel()
        timeCaption.styleAsLabel("en marcha", size: 11, color: AppTheme.textSecondary(0.42), tracking: 1.6)

        let statsRow = UIStackView(arrangedSubviews: [
            activeStatCard(valueLabel: kmValueLabel, caption: "km"),
            activeStatCard(valueLabel: speedValueLabel, caption: "km/h med"),
            activeStatCard(valueLabel: elevationValueLabel, caption: "m+"),
        ])
        statsRow.axis = .horizontal
        statsRow.spacing = 10
        statsRow.distribution = .fillEqually

        let infoStack = UIStackView(arrangedSubviews: [headerRow, timeLabel, timeCaption, statsRow])
        infoStack.axis = .vertical
        // .fill (no .leading): headerRow necesita estirarse a todo el
        // ancho para que su spacer empuje `activeBikeLabel` al borde
        // derecho, y statsRow para que las 3 tarjetas repartan el ancho
        // completo — con `.leading` ambos se quedaban encogidos a su
        // tamaño intrínseco. timeLabel/timeCaption son texto normal, con
        // `.fill` simplemente ocupan el ancho de más sin cambiar cómo se
        // ven (siguen alineados a la izquierda).
        infoStack.alignment = .fill
        infoStack.spacing = 4
        infoStack.setCustomSpacing(14, after: timeCaption)
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        // Tarjeta flotante (cristal oscuro semitransparente + sombra) en
        // vez del bloque opaco de antes que ocupaba su propia franja fija
        // encima del mapa — ahora el mapa va a pantalla completa por
        // detrás y esta tarjeta flota sobre él, dejando mucho más mapa (y
        // trazado) visible, como se pidió.
        let infoCard = UIView()
        infoCard.backgroundColor = AppTheme.bg1.withAlphaComponent(0.88)
        infoCard.layer.cornerRadius = 18
        infoCard.layer.borderWidth = 1
        infoCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        infoCard.layer.shadowColor = UIColor.black.cgColor
        infoCard.layer.shadowOpacity = 0.35
        infoCard.layer.shadowRadius = 16
        infoCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(infoStack)
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 14),
            infoStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -14),
            infoStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14),
        ])

        activeMapWrapper.translatesAutoresizingMaskIntoConstraints = false
        activeMapWrapper.clipsToBounds = true

        // Fin — ancho completo, ámbar, alto (72pt) para pulsarse con
        // guantes. Ya no hay botón de pausar: la grabación corre sin
        // interrupciones desde "Empezar ruta" hasta "Fin".
        let finishIcon = UIImageView(image: UIImage(systemName: "stop.fill"))
        finishIcon.tintColor = AppTheme.bg0
        finishIcon.contentMode = .scaleAspectFit
        finishIcon.translatesAutoresizingMaskIntoConstraints = false
        finishIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let finishLabel = UILabel()
        finishLabel.styleAsLabel("Fin", size: 15, color: AppTheme.bg0, tracking: 1.2)

        let finishContent = UIStackView(arrangedSubviews: [finishIcon, finishLabel])
        finishContent.axis = .horizontal
        finishContent.spacing = 8
        finishContent.alignment = .center
        finishContent.isUserInteractionEnabled = false
        finishContent.translatesAutoresizingMaskIntoConstraints = false

        let finishButton = UIButton(type: .system)
        finishButton.backgroundColor = AppTheme.primary
        finishButton.layer.cornerRadius = 18
        finishButton.layer.shadowColor = AppTheme.primary.cgColor
        finishButton.layer.shadowOpacity = 0.3
        finishButton.layer.shadowRadius = 10
        finishButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        finishButton.heightAnchor.constraint(equalToConstant: 72).isActive = true
        finishButton.addTarget(self, action: #selector(onFinishTapped), for: .touchUpInside)
        finishButton.addSubview(finishContent)
        NSLayoutConstraint.activate([
            finishContent.centerXAnchor.constraint(equalTo: finishButton.centerXAnchor),
            finishContent.centerYAnchor.constraint(equalTo: finishButton.centerYAnchor),
        ])

        let bottomBar = UIView()
        bottomBar.backgroundColor = AppTheme.bg1
        bottomBar.layer.borderWidth = 1
        bottomBar.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(finishButton)
        NSLayoutConstraint.activate([
            finishButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 14),
            finishButton.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            finishButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            finishButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
        ])

        // Orden de capas: mapa primero (a pantalla completa, de fondo),
        // tarjeta de cifras y barra inferior encima flotando — antes el
        // mapa era un hermano más, encajado en el hueco que dejaban las
        // otras dos franjas.
        activeContainer.addSubview(activeMapWrapper)
        activeContainer.addSubview(infoCard)
        activeContainer.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            activeMapWrapper.topAnchor.constraint(equalTo: activeContainer.topAnchor),
            activeMapWrapper.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor),
            activeMapWrapper.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor),
            activeMapWrapper.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            infoCard.topAnchor.constraint(equalTo: activeContainer.safeAreaLayoutGuide.topAnchor, constant: 8),
            infoCard.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor, constant: 12),
            infoCard.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor, constant: -12),

            bottomBar.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: activeContainer.bottomAnchor),
        ])
    }

    private func activeStatCard(valueLabel: UILabel, caption: String) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.cardBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor

        valueLabel.font = AppFont.data(28)
        valueLabel.textColor = AppTheme.text
        valueLabel.text = "0"

        let captionLabel = UILabel()
        captionLabel.styleAsLabel(caption, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 11),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -6),
        ])
        return container
    }

    private func addPulseAnimation(to view: UIView) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.25
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        view.layer.add(animation, forKey: "pulse")
    }

    // MARK: - Cambiar entre reposo/grabando

    private func switchToIdle(animated: Bool) {
        moveMapView(to: idleMapWrapper)
        idleContainer.isHidden = false
        activeContainer.isHidden = true
    }

    private func switchToActive() {
        moveMapView(to: activeMapWrapper)
        idleContainer.isHidden = true
        activeContainer.isHidden = false
    }

    @objc private func onCloseTapped() {
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

    @objc private func onChangeBikeTapped() {
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
    /// Siempre"); en cualquier otro estado ya decidido, `request*` no
    /// dispara ningún delegado nuevo y esperar se quedaría colgado para
    /// siempre.
    private func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        let current = locationManager.authorizationStatus
        guard current == .notDetermined || current == .authorizedWhenInUse else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }

    // MARK: - Grabar ruta

    @objc private func onStartTapped() {
        Task { await startRideFlow() }
    }

    @objc private func onFinishTapped() {
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

        // Pide "siempre" antes de arrancar y ESPERA la respuesta real del
        // diálogo (antes se pedía y se seguía sin más — si el sistema mata
        // las actualizaciones de posición en cuanto la app pasa a segundo
        // plano, la grabación se corta a medias sin que nadie se entere
        // hasta volver y ver el trazado incompleto). Si sigue sin ser
        // "Siempre" tras preguntarle, se avisa antes de empezar, no
        // después de descubrirlo a medias.
        let authorization = await requestAlwaysAuthorization()
        guard authorization == .authorizedAlways else {
            showAlert(
                title: "Falta un permiso",
                message: "Grabar en segundo plano necesita el permiso de ubicación \"Siempre\" — actívalo en "
                    + "Ajustes del sistema antes de empezar. Si no, la grabación puede cortarse al bloquear el móvil.")
            return
        }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        do {
            let ride = try await rideRepository.startRide(riderId: userId, motorbikeId: bike.id)
            currentRide = ride
            trackCoordinates = []
            totalDistanceMeters = 0
            totalElevationGainMeters = 0
            lastAltitude = nil
            rideStartDate = Date()
            UserDefaults.standard.set(ride.id, forKey: Self.pendingRideIdKey)
            activeBikeLabel.styleAsLabel(bike.displayName, size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)
            stateLabel.styleAsLabel("Grabando", size: 12.5, medium: true, color: AppTheme.primary, tracking: 1.4)
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
        let backendPoints = ride.trackPoints.map { StatsPoint(coordinate: $0.coordinate, altitude: $0.altitude) }
        let pendingPoints = trackSyncManager.pendingPoints(forRide: ride.id)
            .map { StatsPoint(coordinate: $0.coordinate, altitude: $0.altitude) }
        let allPoints = backendPoints + pendingPoints

        currentRide = ride
        trackCoordinates = allPoints.map(\.coordinate)
        rideStartDate = ride.startedAt
        (totalDistanceMeters, totalElevationGainMeters) = Self.recomputeStats(from: allPoints)
        lastAltitude = allPoints.last?.altitude

        stateLabel.styleAsLabel("Grabando", size: 12.5, medium: true, color: AppTheme.primary, tracking: 1.4)
        switchToActive()
        redrawTrack()
        startTimer()
        liveActivity.start(motorbikeName: selectedBike?.displayName ?? "")
        trackSyncManager.attemptDrain(rideId: ride.id)
    }

    /// Punto mínimo común entre `TrackPointModel` (lo que ya sabe el
    /// backend) y `PendingTrackPoint` (lo que sigue en cola local) — para
    /// poder recalcular cifras sobre los dos juntos al reanudar una
    /// grabación a medias.
    private struct StatsPoint {
        let coordinate: CLLocationCoordinate2D
        let altitude: Double?
    }

    /// Mismas reglas que al ir sumando en vivo (`didUpdateLocations`), pero
    /// aplicadas de una vez sobre un historial ya grabado.
    private static func recomputeStats(from points: [StatsPoint]) -> (distance: CLLocationDistance, elevationGain: Double) {
        var distance: CLLocationDistance = 0
        var elevationGain: Double = 0
        var lastAltitude: Double?
        for (index, point) in points.enumerated() {
            if index > 0 {
                let previous = points[index - 1]
                distance += CLLocation(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude)
                    .distance(from: CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude))
            }
            if let altitude = point.altitude {
                if let last = lastAltitude {
                    let delta = altitude - last
                    if delta > 1 { elevationGain += delta }
                }
                lastAltitude = altitude
            }
        }
        return (distance, elevationGain)
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
            let pointCount = trackCoordinates.count
            let publishCoordinates = trackCoordinates
            let distanceKm = (totalDistanceMeters / 1000 * 100).rounded() / 100
            let durationMinutes = max(1, Int(Date().timeIntervalSince(rideStartDate ?? Date()) / 60))
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
                        coordinates: publishCoordinates, distanceKm: distanceKm, durationMinutes: durationMinutes),
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
    private func redrawTrack() {
        guard trackCoordinates.count >= 2 else { return }
        var polyline = PolylineAnnotation(lineCoordinates: trackCoordinates)
        polyline.lineColor = StyleColor(AppTheme.primary)
        polyline.lineWidth = 7
        // Borde oscuro alrededor del trazado ámbar — sin él, la línea se
        // mezcla con el fondo claro del estilo `outdoors` en zonas de
        // asfalto/tierra parecidas en tono. Con el borde se recorta igual
        // de bien sobre calles claras que oscuras.
        polyline.lineBorderColor = StyleColor(AppTheme.bg0)
        polyline.lineBorderWidth = 1.6
        polylineManager?.annotations = [polyline]
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateActiveStats() {
        guard let start = rideStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let elapsedSeconds = Int(elapsed)
        timeLabel.text = String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)

        let km = totalDistanceMeters / 1000
        kmValueLabel.text = String(format: "%.1f", km)
        elevationValueLabel.text = String(format: "%.0f", totalElevationGainMeters)
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

        if let previous = trackCoordinates.last {
            totalDistanceMeters += CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        if location.altitude != 0 || lastAltitude != nil {
            if let previousAltitude = lastAltitude {
                let delta = location.altitude - previousAltitude
                if delta > 1 { totalElevationGainMeters += delta }
            }
            lastAltitude = location.altitude
        }
        trackCoordinates.append(coordinate)
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
            timestamp: location.timestamp))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
    }
}
