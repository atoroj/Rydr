import MapboxNavigationCore
import UIKit

/// Cartel de límite de velocidad — cuadrado blanco con borde negro y
/// "MAX XX", como en el mock de Claude Design. No se puede usar
/// `SpeedLimitView` del SDK (mismo problema que `ManeuverView`/`LanesView`:
/// su `init(frame:)` no lleva `public`, así que queda oculta fuera del
/// módulo — confirmado leyendo el fuente), pero el dato en sí sí es
/// público (`MapMatchingState.speedLimit`, el mismo publisher del que ya
/// sale la posición del puck) — esta es una vista propia, sencilla, que
/// solo necesita ese dato.
///
/// De momento un único estilo (el cuadrado blanco tipo MUTCD/EEUU) para
/// cualquier país — replicar también el círculo rojo del Convenio de
/// Viena (Europa) según `SpeedLimit.signStandard` es una mejora aparte,
/// no crítica para que el dato sea útil de un vistazo.
final class RydrSpeedLimitView: UIView {
    private let maxLabel = UILabel()
    private let valueLabel = UILabel()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .white
        layer.cornerRadius = 10
        layer.borderWidth = 2.5
        layer.borderColor = UIColor.black.cgColor
        isHidden = true

        maxLabel.text = "MAX"
        maxLabel.font = AppFont.label(10)
        maxLabel.textColor = .black
        maxLabel.textAlignment = .center

        valueLabel.font = AppFont.data(26)
        valueLabel.textColor = .black
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        let stack = UIStackView(arrangedSubviews: [maxLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 58),
            heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// `nil`/sin valor = tramo sin dato de límite conocido — se oculta el
    /// cartel entero en vez de enseñar un "MAX --" que no aporta nada.
    func update(with speedLimit: SpeedLimit) {
        guard let value = speedLimit.value else {
            isHidden = true
            return
        }
        isHidden = false
        valueLabel.text = "\(Int(value.converted(to: .kilometersPerHour).value.rounded()))"
    }
}
