import UIKit

/// Tipografía del sistema visual: Barlow (cuerpo/títulos), Barlow Condensed
/// (cifras — sus dígitos ya vienen de ancho fijo por diseño, no hace falta
/// activar ninguna característica tabular aparte) y Barlow Semi Condensed
/// (etiquetas en mayúsculas). Fuentes empaquetadas en Resources/Fonts y
/// registradas en project.yml (`UIAppFonts`).
///
/// Si una fuente no carga (registro mal hecho, nombre cambiado...)
/// `UIFont(name:)` devuelve `nil` en silencio — por eso cada helper cae a
/// la fuente del sistema en vez de crashear.
enum AppFont {
    enum Weight {
        case regular, medium, semibold, bold

        fileprivate var barlowName: String {
            switch self {
            case .regular: return "Barlow-Regular"
            case .medium: return "Barlow-Medium"
            case .semibold: return "Barlow-SemiBold"
            case .bold: return "Barlow-Bold"
            }
        }

        fileprivate var systemWeight: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    /// Cuerpo y títulos.
    static func body(_ size: CGFloat, _ weight: Weight = .regular) -> UIFont {
        UIFont(name: weight.barlowName, size: size) ?? .systemFont(ofSize: size, weight: weight.systemWeight)
    }

    /// Cifras/datos (velocidad, km, tiempo...). Solo trae 600/700 — para
    /// cualquier otro peso pedido cae al más cercano.
    static func data(_ size: CGFloat, semibold: Bool = false) -> UIFont {
        let name = semibold ? "BarlowCondensed-SemiBold" : "BarlowCondensed-Bold"
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }

    /// Etiquetas en mayúsculas con tracking amplio — el propio texto debe
    /// pasarse ya en mayúsculas y con `NSAttributedString` para el tracking
    /// (ver `UILabel.styleAsLabel(_:tracking:)` más abajo).
    static func label(_ size: CGFloat, medium: Bool = false) -> UIFont {
        let name = medium ? "BarlowSemiCondensed-Medium" : "BarlowSemiCondensed-SemiBold"
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }
}

extension UILabel {
    /// Aplica el estilo "etiqueta" del sistema de diseño: Barlow Semi
    /// Condensed, mayúsculas y tracking ancho (~0.1em, que a 11pt son ~1.1pt).
    ///
    /// Ojo: usa `attributedText`, así que `textColor` deja de tener efecto
    /// una vez llamado — para cambiar el color después, vuelve a llamar a
    /// este método con el color nuevo (no toques `.textColor` a pelo).
    func styleAsLabel(_ newText: String? = nil, size: CGFloat = 11, medium: Bool = false, color: UIColor? = nil, tracking: CGFloat = 1.1) {
        let resolvedColor = color ?? textColor ?? AppTheme.text
        font = AppFont.label(size, medium: medium)
        let source = newText ?? text ?? ""
        attributedText = NSAttributedString(
            string: source.uppercased(),
            attributes: [.kern: tracking, .foregroundColor: resolvedColor]
        )
    }
}
