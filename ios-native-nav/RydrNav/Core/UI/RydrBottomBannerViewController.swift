import CoreLocation
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// Banner inferior de navegación hecho a mano — sustituye al
/// `BottomBannerViewController` por defecto del SDK, cuya maquetación
/// (constraints privadas) no deja meterle las etiquetas "RESTANTE"/
/// "LLEGADA" como pide el "modo navegación" de Claude Design. El botón de
/// cancelar sí reutiliza `CancelButton` (clase pública del SDK, ya con el
/// estilo cuadrado ámbar de `RydrNavigationStyle`).
final class RydrBottomBannerViewController: UIViewController, NavigationComponent {
    /// `RouteNavigationLauncher` lo rellena tras crear el
    /// `NavigationViewController` — hace falta reproducir exactamente lo
    /// mismo que hacía el delegado por defecto al cancelar (limpiar el
    /// estado del tramo de aproximación en curso, si lo hay).
    var onCancelTapped: (() -> Void)?

    private let distanceValueLabel = UILabel()
    private let etaValueLabel = UILabel()
    private let cancelButton = CancelButton(type: .system)

    private static let etaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg1
        setupUI()
    }

    private func setupUI() {
        let distanceStack = statBlock(valueLabel: distanceValueLabel, caption: "Restante")
        let etaStack = statBlock(valueLabel: etaValueLabel, caption: "Llegada")
        let statsRow = UIStackView(arrangedSubviews: [distanceStack, etaStack])
        statsRow.axis = .horizontal
        statsRow.spacing = 22

        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.widthAnchor.constraint(equalToConstant: 52).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        cancelButton.addTarget(self, action: #selector(onCancel), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [statsRow, UIView(), cancelButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func statBlock(valueLabel: UILabel, caption: String) -> UIView {
        valueLabel.font = AppFont.data(27)
        valueLabel.textColor = AppTheme.text
        let captionLabel = UILabel()
        captionLabel.styleAsLabel(caption, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    // MARK: - NavigationComponent

    func onRouteProgressUpdated(_ progress: RouteProgress) {
        distanceValueLabel.text = Self.formatDistance(progress.distanceRemaining)
        if let arrival = Calendar.current.date(byAdding: .second, value: Int(progress.durationRemaining), to: Date()) {
            etaValueLabel.text = Self.etaFormatter.string(from: arrival)
        }
    }

    private static func formatDistance(_ meters: CLLocationDistance) -> String {
        meters < 1000 ? "\(Int(meters)) m" : String(format: "%.0f km", meters / 1000)
    }

    @objc private func onCancel() {
        onCancelTapped?()
    }
}
