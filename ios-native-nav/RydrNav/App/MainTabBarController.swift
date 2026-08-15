import UIKit

/// Espejo de `_MainShell` (lib/core/router/app_router.dart) — 4 pestañas
/// reales (Actividad, Rutas, Quedadas, Riders) más el botón "Registrar",
/// que abre `RegisterViewController` a pantalla completa en vez de ser una
/// pestaña más. "Mis Rutas" y "Mis Motos" ya no son pestañas — viven
/// dentro del perfil propio (`RiderProfileHeaderCell`: "Ver todas mis
/// rutas" / "Ver mi garaje").
///
/// El panel inferior es la opción **A** de la exploración 1e de Claude
/// Design ("FAB elevado sobre la barra"): una sola barra con las 4
/// pestañas repartidas en 5 columnas iguales, con el botón "Registrar"
/// —un cuadrado redondeado ámbar con un punto oscuro dentro, sin texto—
/// sobresaliendo por encima de la barra justo en el centro. (Antes se
/// usaba la opción B —dos filas, botón de ancho completo arriba— que era
/// la del prototipo navegable real; el usuario pidió cambiar
/// explícitamente a la A.) La propia opción A del documento las lleva
/// solo en texto, pero el usuario pidió recuperar el icono encima de
/// cada etiqueta (los mismos SF Symbols que ya usaba la barra anterior).
/// Al dejar de ser un `UITabBar` del sistema, esta pantalla es un
/// contenedor de view controllers hecho a mano (patrón estándar
/// `addChild`/`didMove`).
final class MainTabBarController: UIViewController {
    private struct Tab {
        let root: UIViewController
        let nav: UINavigationController
        let title: String
        let icon: String
        let selectedIcon: String
    }

    private var tabs: [Tab] = []
    private var selectedIndex = 0
    private let contentContainer = UIView()
    private var tabButtons: [UIButton] = []
    private var tabIconViews: [UIImageView] = []
    private var tabLabels: [UILabel] = []
    private var panel: UIView!
    private var panelBottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0

        tabs = [
            Tab(root: FeedViewController(), nav: UINavigationController(), title: "Actividad",
                icon: "flame", selectedIcon: "flame.fill"),
            Tab(root: RouteListViewController(screenTitle: "Rutas", fetch: { try await RouteRepository().getPublicRoutes() }),
                nav: UINavigationController(), title: "Rutas",
                icon: "point.topleft.down.curvedto.point.bottomright.up", selectedIcon: "point.topleft.down.curvedto.point.bottomright.up"),
            Tab(root: MeetupsViewController(), nav: UINavigationController(), title: "Quedadas",
                icon: "person.3.sequence", selectedIcon: "person.3.sequence.fill"),
            Tab(root: RidersViewController(), nav: UINavigationController(), title: "Riders",
                icon: "person.3", selectedIcon: "person.3.fill"),
        ]
        for tab in tabs {
            tab.nav.setViewControllers([tab.root], animated: false)
        }

        setupContentContainer()
        setupBottomChrome()
        selectTab(0)

        // El teclado se presenta en su propia ventana, por encima de todo
        // lo de la nuestra — sin esto, al enfocar un buscador el teclado
        // tapa directamente el panel inferior (y sus etiquetas) porque los
        // dos están anclados al fondo de la pantalla. Se sube el panel
        // justo por encima del teclado en vez de dejar que lo cubra.
        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onKeyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let durationNumber = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curveNumber = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        else { return }

        let keyboardFrameInView = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.origin.y)
        // El panel ya reserva su propio hueco para el home indicator con
        // `safeAreaLayoutGuide`; al subirlo por encima del teclado ese
        // hueco deja de hacer falta (el teclado ya cubre esa zona), así
        // que se descuenta para que no quede un salto de más.
        panelBottomConstraint.constant = -max(0, overlap - view.safeAreaInsets.bottom)

        let options = UIView.AnimationOptions(rawValue: curveNumber.uintValue << 16)
        UIView.animate(withDuration: durationNumber.doubleValue, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Contenedor de pantallas

    private func setupContentContainer() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func selectTab(_ index: Int) {
        let previous = tabs.indices.contains(selectedIndex) ? tabs[selectedIndex] : nil
        let next = tabs[index]

        if let previous, previous.nav !== next.nav {
            previous.nav.willMove(toParent: nil)
            previous.nav.view.removeFromSuperview()
            previous.nav.removeFromParent()
        }

        if next.nav.parent == nil {
            addChild(next.nav)
            next.nav.view.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(next.nav.view)
            NSLayoutConstraint.activate([
                next.nav.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                next.nav.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                next.nav.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                next.nav.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            ])
            next.nav.didMove(toParent: self)
        }

        selectedIndex = index
        updateTabAppearance()
    }

    // MARK: - Panel inferior: barra de 5 columnas + FAB "Registrar" elevado

    private func setupBottomChrome() {
        let panel = UIView()
        self.panel = panel
        panel.backgroundColor = AppTheme.bg1
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        panel.layer.cornerRadius = 14
        // Solo las esquinas de arriba — abajo va a ras del borde de la
        // pantalla, como cualquier barra de pestañas normal.
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.translatesAutoresizingMaskIntoConstraints = false

        // 4 pestañas icono+etiqueta — la opción A del 1e las lleva solo en
        // texto, pero se recupera aquí el icono (mismos SF Symbols de
        // antes) encima de cada una, a petición.
        for (index, tab) in tabs.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.addTarget(self, action: #selector(onTabTapped(_:)), for: .touchUpInside)

            let iconView = UIImageView(image: UIImage(systemName: tab.icon))
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 27).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 27).isActive = true
            iconView.isUserInteractionEnabled = false

            let label = UILabel()
            label.styleAsLabel(tab.title, size: 9.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 1)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false

            let column = UIStackView(arrangedSubviews: [iconView, label])
            column.axis = .vertical
            column.spacing = 5
            column.alignment = .center
            column.isUserInteractionEnabled = false
            column.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(column)
            NSLayoutConstraint.activate([
                column.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                column.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 2),
                column.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -2),
                column.topAnchor.constraint(greaterThanOrEqualTo: button.topAnchor, constant: 4),
                column.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -14),
            ])

            tabButtons.append(button)
            tabIconViews.append(iconView)
            tabLabels.append(label)
        }

        // La columna del medio (donde sobresale el FAB) es un hueco sin
        // toque — el propio botón "Registrar" va encima, no dentro de la
        // barra, para que pueda sobresalir por arriba.
        let fabSpacer = UIView()

        // De vuelta a las 5 columnas iguales a todo lo ancho de la barra
        // (como en la captura de la opción A del 1e) — el paso por
        // columnas ajustadas al contenido dejaba los botones demasiado
        // juntos entre sí, ya no se parecía a la referencia.
        let tabStrip = UIStackView(arrangedSubviews: [
            tabButtons[0], tabButtons[1], fabSpacer, tabButtons[2], tabButtons[3],
        ])
        tabStrip.axis = .horizontal
        tabStrip.distribution = .fillEqually
        tabStrip.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(tabStrip)

        view.addSubview(panel)
        panelBottomConstraint = panel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottomConstraint,
            panel.topAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            // El hueco de arriba (26pt) es donde se mete la mitad de
            // arriba del FAB; las etiquetas quedan pegadas abajo del
            // todo, encima del home indicator.
            tabStrip.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            tabStrip.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -2),
            tabStrip.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            tabStrip.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
        ])

        setupFAB()
    }

    /// El botón "Registrar": un cuadrado redondeado ámbar con un punto
    /// oscuro dentro (sin texto — así lo lleva la opción A del 1e), a
    /// pantalla completa por delante de todo, centrado sobre la columna
    /// del medio de `tabStrip` y con el centro apoyado justo en el borde
    /// superior del panel, así que la mitad de arriba sobresale por
    /// encima de la barra y la mitad de abajo queda dentro.
    private func setupFAB() {
        let fab = UIButton(type: .system)
        fab.accessibilityLabel = "Registrar"
        fab.backgroundColor = AppTheme.primary
        fab.layer.cornerRadius = 27
        fab.layer.shadowColor = AppTheme.primary.cgColor
        fab.layer.shadowOpacity = 0.4
        fab.layer.shadowRadius = 14
        fab.layer.shadowOffset = .zero
        fab.translatesAutoresizingMaskIntoConstraints = false
        fab.addTarget(self, action: #selector(onRegisterTapped), for: .touchUpInside)

        let dot = UIView()
        dot.backgroundColor = AppTheme.bg0
        dot.layer.cornerRadius = 11
        dot.isUserInteractionEnabled = false
        dot.translatesAutoresizingMaskIntoConstraints = false
        fab.addSubview(dot)

        view.addSubview(fab)
        NSLayoutConstraint.activate([
            fab.widthAnchor.constraint(equalToConstant: 70),
            fab.heightAnchor.constraint(equalToConstant: 70),
            fab.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fab.centerYAnchor.constraint(equalTo: panel.topAnchor),

            dot.widthAnchor.constraint(equalToConstant: 30),
            dot.heightAnchor.constraint(equalToConstant: 30),
            dot.centerXAnchor.constraint(equalTo: fab.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: fab.centerYAnchor),
        ])
    }

    private func updateTabAppearance() {
        for (index, tab) in tabs.enumerated() {
            let selected = index == selectedIndex
            let color = selected ? AppTheme.primary : AppTheme.textSecondary(0.45)
            tabIconViews[index].image = UIImage(systemName: selected ? tab.selectedIcon : tab.icon)
            tabIconViews[index].tintColor = color
            tabLabels[index].styleAsLabel(tab.title, size: 9.5, medium: true, color: color, tracking: 1)
        }
    }

    @objc private func onTabTapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectTab(sender.tag)
    }

    @objc private func onRegisterTapped() {
        let register = UINavigationController(rootViewController: RegisterViewController())
        register.modalPresentationStyle = .fullScreen
        present(register, animated: true)
    }
}
