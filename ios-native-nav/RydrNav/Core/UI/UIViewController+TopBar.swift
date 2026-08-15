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
        avatarButton.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
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
        let placeholder = initialPlaceholder(for: user.username)
        button.setImage(placeholder, for: .normal)
        guard let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty,
              let url = RemoteImageView.resolvedURL(avatarUrl)
        else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { button.setImage(image, for: .normal) }
        }.resume()
    }

    /// Iniciales sobre el degradado cálido→frío que usa el mock para el
    /// avatar sin foto (`linear-gradient(150deg,#3a2a22,#1b1e23)`).
    private func initialPlaceholder(for username: String) -> UIImage {
        let size = CGSize(width: 36, height: 36)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [UIColor(hex: 0x3A2A22).cgColor, UIColor(hex: 0x1B1E23).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            let initial = String(username.prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: AppFont.body(15, .semibold), .foregroundColor: UIColor(hex: 0xFFC768),
            ]
            let textSize = initial.size(withAttributes: attrs)
            initial.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attrs)
        }
    }

    @objc private func onAvatarTapped() {
        navigationController?.pushViewController(RiderProfileViewController(userId: nil), animated: true)
    }

    @objc private func onSettingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
}
