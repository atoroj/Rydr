import UIKit

/// Instala la top bar común a las 4 pestañas del shell: avatar circular a
/// la izquierda (abre el perfil social), el lockup del logo "Rastro" +
/// "RYDR" en el centro, y el engranaje de ajustes a la derecha — espejo de
/// la `AppBar` que monta `_MainShell` (lib/core/router/app_router.dart) y
/// de la cabecera `is.chrome` del prototipo de Claude Design. Cada root
/// view controller de tab la llama una vez en `viewDidLoad`.
extension UIViewController {
    func installTopBar() {
        let avatarButton = UIButton(type: .system)
        // Antes solo se fijaba `.frame`, sin constraints — bastaba con
        // `UIBarButtonItem(customView:)` para que Auto Layout lo
        // recalculara según el `intrinsicContentSize` del botón (que
        // depende de la imagen puesta), así que en cuanto la imagen de
        // iniciales pasó a generarse a 200×200 (para verse nítida en
        // avatares grandes de toda la app) el botón se salía de su
        // tamaño de 36pt en vez de quedarse recortado a él.
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        avatarButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        avatarButton.layer.cornerRadius = 18
        avatarButton.clipsToBounds = true
        avatarButton.layer.borderWidth = 1.5
        avatarButton.layer.borderColor = AppTheme.primary.withAlphaComponent(0.55).cgColor
        avatarButton.imageView?.contentMode = .scaleAspectFill
        avatarButton.addTarget(self, action: #selector(onAvatarTapped), for: .touchUpInside)
        refreshAvatarButton(avatarButton)
        NotificationCenter.default.addObserver(
            forName: .authDidChange, object: nil, queue: .main
        ) { [weak self, weak avatarButton] _ in
            guard let avatarButton else { return }
            self?.refreshAvatarButton(avatarButton)
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: avatarButton)
        navigationItem.titleView = Self.makeBrandLockup()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"), style: .plain,
            target: self, action: #selector(onSettingsTapped))
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textSecondary(0.75)
    }

    /// El lockup "Rastro" + "RYDR" que usa el prototipo en la cabecera de
    /// cada pantalla — constante, no cambia según la pestaña activa (así
    /// es como lo hace el propio diseño: los títulos de sección van dentro
    /// del contenido, no en la barra).
    private static func makeBrandLockup() -> UIView {
        let logo = RydrLogoView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 19).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 19).isActive = true

        let wordmark = UILabel()
        wordmark.attributedText = NSAttributedString(string: "RYDR", attributes: [
            .font: AppFont.data(19), .foregroundColor: AppTheme.text, .kern: 2.6,
        ])

        let stack = UIStackView(arrangedSubviews: [logo, wordmark])
        stack.axis = .horizontal
        stack.spacing = 7
        stack.alignment = .center
        return stack
    }

    private func refreshAvatarButton(_ button: UIButton) {
        guard let user = AuthManager.shared.currentUser else { return }
        // `RemoteImageView.initialsAvatar` — mismo dibujo de iniciales
        // (nombre+apellido en ámbar) que usa el resto de avatares de la
        // app, no una versión propia solo para la top bar. Con el tamaño
        // exacto del botón: a diferencia de un `UIImageView` normal (que
        // sí escala su imagen al tamaño de la vista según `contentMode`),
        // un `UIButton.setImage` centra la imagen a su tamaño natural sin
        // escalarla — con el tamaño de referencia grande (200×200) que
        // usa el resto de avatares se veía solo un recorte diminuto sin
        // escalar del centro de la imagen.
        // `.alwaysOriginal`: un `UIButton(type: .system)` trata cualquier
        // imagen puesta con `setImage` como plantilla por defecto y la
        // tiñe entera con `tintColor` (aquí, el ámbar de marca) — sin
        // esto, tanto el degradado+letra como la foto real de perfil se
        // veían como un círculo ámbar liso, sin ningún detalle propio.
        button.setImage(
            RemoteImageView.initialsAvatar(for: user.username, size: CGSize(width: 36, height: 36))
                .withRenderingMode(.alwaysOriginal),
            for: .normal)
        guard let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty,
              let url = RemoteImageView.resolvedURL(avatarUrl)
        else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal) }
        }.resume()
    }

    @objc private func onAvatarTapped() {
        navigationController?.pushViewController(RiderProfileViewController(userId: nil), animated: true)
    }

    @objc private func onSettingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
}
