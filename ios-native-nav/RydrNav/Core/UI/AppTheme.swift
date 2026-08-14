import UIKit

/// Espejo de lib/core/theme/app_theme.dart — mismo color de marca.
enum AppTheme {
    static let primary = UIColor(red: 0xE8 / 255, green: 0x50 / 255, blue: 0x1A / 255, alpha: 1)

    // Tamaños táctiles grandes: pensados para pulsarse con guantes de moto
    // puestos, no con la precisión de un dedo desnudo.
    static let gloveButtonHeight: CGFloat = 56
    static let gloveIconSize: CGFloat = 28
}
