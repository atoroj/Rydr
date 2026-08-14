import UIKit

/// Instala la top bar común a las 4 pestañas del shell: avatar circular a
/// la izquierda (abre el perfil social) y engranaje de ajustes a la
/// derecha — espejo de la `AppBar` que monta `_MainShell`
/// (lib/core/router/app_router.dart). Cada root view controller de tab la
/// llama una vez en `viewDidLoad`.
extension UIViewController {
    func installTopBar() {
        let avatarButton = UIButton(type: .system)
        avatarButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        avatarButton.layer.cornerRadius = 16
        avatarButton.clipsToBounds = true
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"), style: .plain,
            target: self, action: #selector(onSettingsTapped))
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

    private func initialPlaceholder(for username: String) -> UIImage {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            AppTheme.primary.withAlphaComponent(0.3).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let initial = String(username.prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: UIColor.white,
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
