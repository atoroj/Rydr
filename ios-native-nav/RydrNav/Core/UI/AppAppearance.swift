import UIKit

/// Apariencia global de `UINavigationBar` — barra oscura (`bg1`) coherente
/// con el resto del sistema visual en vez del blur claro por defecto. Se
/// llama una sola vez, al arrancar (`AppDelegate`).
enum AppAppearance {
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = AppTheme.bg1
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: AppTheme.text, .font: AppFont.body(17, .semibold)]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = AppTheme.primary
    }
}
