import UIKit

/// Espejo de `_MainShell` (lib/core/router/app_router.dart) — 4 pestañas
/// reales (Actividad, Rutas, Quedadas, Riders) más el botón "Registrar",
/// que abre `RegisterViewController` a pantalla completa en vez de ser una
/// pestaña más. "Mis Rutas" y "Mis Motos" ya no son pestañas — viven
/// dentro del perfil propio (`RiderProfileHeaderCell`: "Ver todas mis
/// rutas" / "Ver mi garaje").
///
/// Vuelve a ser un `UITabBarController` de verdad — el contenedor a mano
/// (`addChild`/`didMove` + panel propio) que se usó durante el rediseño
/// era necesario para el FAB elevado de la opción A de la exploración 1e,
/// pero el usuario pidió el cristal que da iOS "por defecto" (como el que
/// ya trae `UITabBar` en iOS 26 — Liquid Glass del sistema, sin construir
/// nada a mano) y eso solo se consigue con la tab bar real del sistema,
/// no reconstruyéndola. El botón "Registrar" vuelve a la disposición del
/// primer diseño que propuso Claude Design: una franja de ancho completo
/// con sombra ámbar, flotando encima de la tab bar (no es una pestaña más).
final class MainTabBarController: UITabBarController {
    private let registerButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupTabs()
        setupRegisterButton()
    }

    // MARK: - Pestañas (tab bar real del sistema)

    private func setupTabs() {
        let feedNav = navController(
            root: FeedViewController(), title: "Actividad", icon: "flame", selectedIcon: "flame.fill")
        let routesNav = navController(
            root: RouteListViewController(screenTitle: "Rutas", fetch: { try await RouteRepository().getPublicRoutes() }),
            title: "Rutas", icon: "point.topleft.down.curvedto.point.bottomright.up",
            selectedIcon: "point.topleft.down.curvedto.point.bottomright.up")
        let meetupsNav = navController(
            root: MeetupsViewController(), title: "Quedadas",
            icon: "person.3.sequence", selectedIcon: "person.3.sequence.fill")
        let ridersNav = navController(
            root: RidersViewController(), title: "Riders", icon: "person.3", selectedIcon: "person.3.fill")

        viewControllers = [feedNav, routesNav, meetupsNav, ridersNav]

        // El propio sistema pinta el material de cristal (Liquid Glass en
        // iOS 26, esmerilado normal antes) — aquí solo hace falta el
        // color de marca para seleccionado/no seleccionado.
        tabBar.tintColor = AppTheme.primary
        tabBar.unselectedItemTintColor = AppTheme.textSecondary(0.45)
    }

    private func navController(
        root: UIViewController, title: String, icon: String, selectedIcon: String
    ) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.tabBarItem = UITabBarItem(
            title: title, image: UIImage(systemName: icon),
            selectedImage: UIImage(systemName: selectedIcon))
        return nav
    }

    // MARK: - Botón "Registrar": franja ámbar flotando sobre la tab bar

    private func setupRegisterButton() {
        registerButton.backgroundColor = AppTheme.primary
        registerButton.layer.cornerRadius = 17
        registerButton.layer.shadowColor = AppTheme.primary.cgColor
        registerButton.layer.shadowOpacity = 0.45
        registerButton.layer.shadowRadius = 16
        registerButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        registerButton.translatesAutoresizingMaskIntoConstraints = false
        registerButton.addTarget(self, action: #selector(onRegisterTapped), for: .touchUpInside)

        let dot = UIView()
        dot.backgroundColor = AppTheme.bg0
        dot.layer.cornerRadius = 8.5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 17).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 17).isActive = true
        dot.isUserInteractionEnabled = false

        let label = UILabel()
        label.text = "REGISTRAR"
        label.font = AppFont.body(18, .bold)
        label.textColor = AppTheme.bg0
        label.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [dot, label])
        row.axis = .horizontal
        row.spacing = 11
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        registerButton.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: registerButton.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: registerButton.centerYAnchor),
        ])

        view.addSubview(registerButton)
        NSLayoutConstraint.activate([
            registerButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            registerButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            // Pegado justo encima de la tab bar real, no dentro — es una
            // franja aparte, no una pestaña más.
            registerButton.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -10),
            registerButton.heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    @objc private func onRegisterTapped() {
        let register = UINavigationController(rootViewController: RegisterViewController())
        register.modalPresentationStyle = .fullScreen
        present(register, animated: true)
    }
}
