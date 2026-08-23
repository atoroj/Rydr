import UIKit

/// El logo "Rastro" — tres trazos horizontales escalonados en diagonal
/// (adelantamiento / ritmo / grupo). Una de las 4 propuestas de Claude
/// Design (`claude.ai/design/p/2c686c03-fef0-4f05-8c67-579fb2501008`,
/// opción 1c); es la que ya usaba el prototipo navegable como icono de
/// facto en la top bar, y la elegida para toda la app.
///
/// Vectorial (CAShapeLayer), se reescala solo con el tamaño del propio
/// view — dale el ancho/alto que quieras por Auto Layout.
final class RydrLogoView: UIView {
    var strokeColor: UIColor = AppTheme.primary {
        didSet { shapeLayer.strokeColor = strokeColor.cgColor }
    }

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds

        // Path original: "M6 34h12M14 24h12M22 14h12" en un viewBox 48x48.
        let scale = min(bounds.width, bounds.height) / 48
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 6 * scale, y: 34 * scale))
        path.addLine(to: CGPoint(x: 18 * scale, y: 34 * scale))
        path.move(to: CGPoint(x: 14 * scale, y: 24 * scale))
        path.addLine(to: CGPoint(x: 26 * scale, y: 24 * scale))
        path.move(to: CGPoint(x: 22 * scale, y: 14 * scale))
        path.addLine(to: CGPoint(x: 34 * scale, y: 14 * scale))

        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = max(1.5, 5 * scale)
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 24, height: 24) }
}
