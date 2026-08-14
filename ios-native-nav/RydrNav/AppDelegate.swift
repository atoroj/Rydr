import UIKit

/// Ciclo de vida clásico de una sola ventana (sin UIScene): más simple y con
/// menos piezas que puedan fallar que el sistema de escenas multi-ventana.
///
/// Hace de "router" mínimo: decide entre login y la app principal según haya
/// o no sesión guardada — equivalente al `redirect` de go_router
/// (lib/core/router/app_router.dart).
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        // Dark mode fijo: es el modo "ideal para conducción" que pide el
        // spec (menos deslumbramiento de noche, mejor contraste con sol
        // directo que un fondo blanco). La UI ya usa colores semánticos
        // (.systemBackground, .label...) así que se adapta sola.
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = AuthManager.shared.isLoggedIn
            ? MainTabBarController()
            : UINavigationController(rootViewController: LoginViewController())
        window.makeKeyAndVisible()
        self.window = window

        // Reacciona a la sesión expirando en segundo plano (401 de
        // APIClient → AuthManager pone currentUser a nil) volviendo sola al
        // login, en vez de dejar la app "logueada" en apariencia mientras
        // cada petición autenticada falla en silencio.
        NotificationCenter.default.addObserver(
            forName: .authDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if AuthManager.shared.isLoggedIn {
                if !(self.window?.rootViewController is MainTabBarController) { self.showMain() }
            } else {
                if !(self.window?.rootViewController is UINavigationController) { self.showLogin() }
            }
        }

        return true
    }

    func showMain() {
        transitionRoot(to: MainTabBarController())
    }

    func showLogin() {
        transitionRoot(to: UINavigationController(rootViewController: LoginViewController()))
    }

    private func transitionRoot(to viewController: UIViewController) {
        guard let window else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = viewController
        }
    }
}
