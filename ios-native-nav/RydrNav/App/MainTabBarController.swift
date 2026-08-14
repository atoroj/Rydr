import UIKit

/// Espejo de `_MainShell` (lib/core/router/app_router.dart) — 4 pestañas
/// reales (Actividad, Rutas, Quedadas, Riders) más un botón circular
/// "Registrar" incrustado sobre la barra, que abre `RegisterViewController`
/// a pantalla completa en vez de ser un tab más. "Mis Rutas" y "Mis Motos"
/// ya no son pestañas — viven dentro del perfil propio
/// (`RiderProfileHeaderCell`: "Ver todas mis rutas" / "Ver mi garaje"), su
/// sitio en la barra lo ocupa "Quedadas" y la portada es el feed de actividad.
///
/// `UITabBarController` no soporta un botón embebido de forma nativa; en
/// vez de subclasificar `UITabBar` con un recorte (frágil, se rompe con
/// cambios de tamaño/orientación), se añade un `UIButton` circular como
/// subvista de este propio `view`, solapando el borde superior de la tab
/// bar — el mismo patrón que usan apps de cámara para su disparador.
final class MainTabBarController: UITabBarController {
    private let registerButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.tintColor = AppTheme.primary

        let feed = wrap(FeedViewController(), title: "Actividad", icon: "flame")
        let routes = wrap(
            RouteListViewController(screenTitle: "Rutas", fetch: { try await RouteRepository().getPublicRoutes() }),
            title: "Rutas", icon: "point.topleft.down.curvedto.point.bottomright.up")
        let meetups = wrap(MeetupsViewController(), title: "Quedadas", icon: "person.3.sequence")
        let riders = wrap(RidersViewController(), title: "Riders", icon: "person.3")

        viewControllers = [feed, routes, meetups, riders]

        setupRegisterButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // La tab bar no tiene su tamaño final hasta después del primer
        // layout — se posiciona aquí en vez de en viewDidLoad.
        let size: CGFloat = 64
        registerButton.frame = CGRect(
            x: view.bounds.midX - size / 2,
            y: tabBar.frame.minY - size / 2 - 6,
            width: size, height: size)
    }

    private func setupRegisterButton() {
        registerButton.backgroundColor = AppTheme.primary
        registerButton.tintColor = .white
        registerButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        registerButton.imageView?.contentMode = .scaleAspectFit
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        registerButton.setPreferredSymbolConfiguration(iconConfig, forImageIn: .normal)
        registerButton.layer.cornerRadius = 32
        registerButton.layer.shadowColor = UIColor.black.cgColor
        registerButton.layer.shadowOpacity = 0.3
        registerButton.layer.shadowRadius = 6
        registerButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        registerButton.accessibilityLabel = "Registrar ruta"
        registerButton.addTarget(self, action: #selector(onRegisterTapped), for: .touchUpInside)
        view.addSubview(registerButton)
    }

    @objc private func onRegisterTapped() {
        let register = UINavigationController(rootViewController: RegisterViewController())
        register.modalPresentationStyle = .fullScreen
        present(register, animated: true)
    }

    private func wrap(_ root: UIViewController, title: String, icon: String) -> UIViewController {
        let nav = UINavigationController(rootViewController: root)
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), tag: 0)
        return nav
    }
}
