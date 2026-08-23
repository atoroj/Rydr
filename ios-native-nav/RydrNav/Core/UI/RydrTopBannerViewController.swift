import Combine
import CoreLocation
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// Flecha de maniobra dibujada a mano — `ManeuverView`, la vista real del
/// SDK con el dibujo curvo real (glifo por tipo de maniobra), no es
/// alcanzable desde aquí: declara `override init(frame: CGRect)` sin
/// `public`, así que ese inicializador queda oculto fuera del módulo del
/// SDK (confirmado leyendo el fuente — `ManeuverView.swift`/`LanesView.swift`
/// solo dejan público `init?(coder:)`, pensado para Interface Builder, no
/// para crearla a mano en código). Esta es una aproximación honesta: una
/// única flecha (SF Symbol) rotada según `ManeuverDirection` — no la
/// animación curva exacta del SDK, pero reconocible de un vistazo, que es
/// lo que importa conduciendo. Se reutiliza también, más pequeña, para
/// cada carril de la fila inferior.
final class RydrManeuverArrowView: UIView {
    private let imageView = UIImageView()

    init(pointSize: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(
            systemName: "arrow.up",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold))
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func update(direction: ManeuverDirection?, color: UIColor) {
        imageView.tintColor = color
        imageView.transform = CGAffineTransform(rotationAngle: Self.angle(for: direction) * .pi / 180)
    }

    private static func angle(for direction: ManeuverDirection?) -> CGFloat {
        switch direction {
        case .sharpRight: return 130
        case .right: return 90
        case .slightRight: return 45
        case .slightLeft: return -45
        case .left: return -90
        case .sharpLeft: return -130
        case .uTurn: return 180
        case .straightAhead, .undefined, .none: return 0
        }
    }
}

/// Banner superior de navegación hecho a mano — sustituye al
/// `TopBannerViewController` por defecto del SDK para poder llevar una fila
/// de carriles propia pegada justo debajo, con una disposición fiel al
/// "modo navegación" de Claude Design: flecha + distancia grande + calle,
/// todo en ámbar sólido.
///
/// Huecos de fidelidad reales frente al mock: la matrícula de carretera
/// ("N-621") sale como texto normal, no como el recuadro tipo señal que
/// dibuja el SDK — ese dibujo vive en `InstructionPresenter`, clase interna
/// del módulo (no `public`). Y la flecha de giro/carriles es una
/// aproximación propia (ver ``RydrManeuverArrowView``), no el glifo curvo
/// real del SDK — su vista (`ManeuverView`/`LanesView`) tampoco es
/// construible desde fuera del módulo.
final class RydrTopBannerViewController: UIViewController, NavigationComponent {
    private let maneuverArrow = RydrManeuverArrowView(pointSize: 30)
    private let distanceValueLabel = UILabel()
    private let distanceUnitLabel = UILabel()
    private let instructionLabel = UILabel()
    private let lanesStack = UIStackView()
    private let speedLimitView = RydrSpeedLimitView()
    private var lanesHeightConstraint: NSLayoutConstraint!

    // El límite de velocidad no llega por `NavigationComponent` (que solo
    // avisa de progreso de ruta e instrucciones) — es parte de
    // `MapMatchingState`, el mismo publisher del que ya sale la posición
    // del puck, así que hace falta suscribirse aparte.
    private let speedLimitPublisher: AnyPublisher<SpeedLimit, Never>
    private var cancellables = Set<AnyCancellable>()

    init(speedLimitPublisher: AnyPublisher<SpeedLimit, Never>) {
        self.speedLimitPublisher = speedLimitPublisher
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.primary
        setupUI()
        speedLimitPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.speedLimitView.update(with: $0) }
            .store(in: &cancellables)
    }

    private func setupUI() {
        maneuverArrow.widthAnchor.constraint(equalToConstant: 42).isActive = true
        maneuverArrow.heightAnchor.constraint(equalToConstant: 42).isActive = true

        distanceValueLabel.font = AppFont.data(38)
        distanceValueLabel.textColor = AppTheme.bg0
        distanceUnitLabel.font = AppFont.body(15, .semibold)
        distanceUnitLabel.textColor = AppTheme.bg0.withAlphaComponent(0.7)
        let distanceRow = UIStackView(arrangedSubviews: [distanceValueLabel, distanceUnitLabel])
        distanceRow.axis = .horizontal
        distanceRow.spacing = 3
        distanceRow.alignment = .lastBaseline

        instructionLabel.font = AppFont.body(17, .semibold)
        instructionLabel.textColor = AppTheme.bg0
        instructionLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [distanceRow, instructionLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let topRow = UIStackView(arrangedSubviews: [maneuverArrow, textStack])
        topRow.axis = .horizontal
        topRow.spacing = 14
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        lanesStack.axis = .horizontal
        lanesStack.spacing = 10
        lanesStack.alignment = .center
        lanesStack.translatesAutoresizingMaskIntoConstraints = false
        lanesHeightConstraint = lanesStack.heightAnchor.constraint(equalToConstant: 0)
        lanesHeightConstraint.isActive = true

        view.addSubview(topRow)
        view.addSubview(speedLimitView)
        view.addSubview(lanesStack)
        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(lessThanOrEqualTo: speedLimitView.leadingAnchor, constant: -12),

            speedLimitView.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
            speedLimitView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            lanesStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 12),
            lanesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            lanesStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            lanesStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - NavigationComponent

    func onDidPassVisualInstructionPoint(_ instruction: VisualInstructionBanner) {
        update(with: instruction)
    }

    func onRouteProgressUpdated(_ progress: RouteProgress) {
        let stepProgress = progress.currentLegProgress.currentStepProgress
        if let instruction = stepProgress.currentVisualInstruction {
            update(with: instruction)
        }
        let (value, unit) = Self.formatDistance(stepProgress.distanceRemaining)
        distanceValueLabel.text = value
        distanceUnitLabel.text = unit
    }

    private func update(with instruction: VisualInstructionBanner) {
        let primary = instruction.primaryInstruction
        maneuverArrow.update(direction: primary.maneuverDirection, color: AppTheme.bg0)

        var text = primary.text ?? ""
        if let secondary = instruction.secondaryInstruction?.text, !secondary.isEmpty {
            text += "  ·  " + secondary
        }
        instructionLabel.text = text

        updateLanes(with: instruction.tertiaryInstruction?.components ?? [])
    }

    /// Solo se muestra si de verdad hay carriles que elegir — la mayor
    /// parte del trayecto no los trae. Cada carril es una flecha propia
    /// (ver ``RydrManeuverArrowView``) en ámbar si es un carril válido para
    /// la maniobra, atenuada en el resto — el mismo lenguaje visual que
    /// cualquier app de navegación real.
    private func updateLanes(with components: [VisualInstruction.Component]) {
        lanesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var hasLanes = false
        for component in components {
            guard case let .lane(indications, isUsable, preferredDirection) = component else { continue }
            hasLanes = true
            let lane = RydrManeuverArrowView(pointSize: 16)
            lane.widthAnchor.constraint(equalToConstant: 24).isActive = true
            lane.heightAnchor.constraint(equalToConstant: 24).isActive = true
            let direction = preferredDirection ?? Self.primaryDirection(in: indications)
            let color = isUsable ? AppTheme.bg0 : AppTheme.bg0.withAlphaComponent(0.3)
            lane.update(direction: direction, color: color)
            lanesStack.addArrangedSubview(lane)
        }
        lanesHeightConstraint.constant = hasLanes ? 30 : 0
    }

    /// `LaneIndication` es un `OptionSet` — un carril puede admitir varias
    /// direcciones a la vez (p.ej. de frente y a la derecha). Sin un
    /// `preferredDirection` explícito del propio carril, se elige una sola
    /// para dibujar, en el orden en que un motorista las escanearía.
    private static func primaryDirection(in indications: LaneIndication) -> ManeuverDirection? {
        if indications.contains(.straightAhead) { return .straightAhead }
        if indications.contains(.slightRight) { return .slightRight }
        if indications.contains(.right) { return .right }
        if indications.contains(.sharpRight) { return .sharpRight }
        if indications.contains(.slightLeft) { return .slightLeft }
        if indications.contains(.left) { return .left }
        if indications.contains(.sharpLeft) { return .sharpLeft }
        if indications.contains(.uTurn) { return .uTurn }
        return nil
    }

    /// Redondea a los 25m más cercanos por debajo de 1km (como la mayoría
    /// de apps de navegación), y a un decimal de km por encima — nada
    /// oficial del SDK, un formateo propio sencillo y honesto.
    private static func formatDistance(_ meters: CLLocationDistance) -> (value: String, unit: String) {
        if meters < 1000 {
            let rounded = max(0, Int((meters / 25).rounded()) * 25)
            return ("\(rounded)", "m")
        }
        return (String(format: "%.1f", meters / 1000), "km")
    }
}
