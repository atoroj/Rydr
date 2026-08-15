import UIKit

/// Sistema visual de Rydr — salido de la exploración de Claude Design
/// (`claude.ai/design/p/2c686c03-fef0-4f05-8c67-579fb2501008`, opción 1b
/// "Sistema visual", paleta Hi-Vis elegida). Fondo frío de una sola
/// familia de grises + un único color de marca de máximo contraste
/// (pensado para leerse con guantes/visera ahumada de día).
enum AppTheme {
    /// Fondo de pantalla.
    static let bg0 = UIColor(hex: 0x0B0C0E)
    /// Barras (top bar, chrome inferior).
    static let bg1 = UIColor(hex: 0x101216)
    /// Tarjeta.
    static let bg2 = UIColor(hex: 0x14161A)
    /// Superficie elevada (hojas modales, botones secundarios).
    static let bg3 = UIColor(hex: 0x1B1E23)
    /// Texto principal.
    static let text = UIColor(hex: 0xF2F3F5)

    /// Hi-Vis — color de marca. Elegido sobre "Ember" (#FF5A1F) y "Signal"
    /// (#C8F04A) por ser el de mayor contraste con guantes y visera ahumada.
    static let primary = UIColor(hex: 0xFFB020)
    /// Acento secundario — "GPS fijado" / tramo de aproximación a una ruta.
    static let accentTeal = UIColor(hex: 0x7DD3C0)

    /// Texto secundario a distintos niveles de énfasis (blanco a opacidad
    /// variable, tal como usa el propio documento de diseño).
    static func textSecondary(_ opacity: CGFloat = 0.6) -> UIColor {
        text.withAlphaComponent(opacity)
    }

    static let cardBackground = bg2
    static let cardBorder = UIColor.white.withAlphaComponent(0.07)
    static let cardRadius: CGFloat = 16

    // Tamaños táctiles grandes: pensados para pulsarse con guantes de moto
    // puestos, no con la precisión de un dedo desnudo.
    static let gloveButtonHeight: CGFloat = 56
    static let gloveIconSize: CGFloat = 28
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
