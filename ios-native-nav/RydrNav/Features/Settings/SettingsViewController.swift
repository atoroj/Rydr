import PhotosUI
import UIKit

/// Ajustes: avatar, nombre, cuenta privada, acceso al historial de rides y
/// cerrar sesión. Abierta desde el engranaje de la top bar — distinta del
/// perfil social (que se abre pulsando el avatar): aquí vive la gestión de
/// la cuenta, allí el escaparate público del rider. Espejo de
/// lib/features/settings/presentation/settings_screen.dart.
final class SettingsViewController: UIViewController {
    private let avatarButton = UIButton(type: .system)
    private let usernameLabel = UILabel()
    private let emailLabel = UILabel()
    private let privacySwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ajustes"
        view.backgroundColor = .systemBackground
        setupUI()
        populate()
    }

    private func setupUI() {
        avatarButton.frame = CGRect(x: 0, y: 0, width: 96, height: 96)
        avatarButton.layer.cornerRadius = 48
        avatarButton.clipsToBounds = true
        avatarButton.imageView?.contentMode = .scaleAspectFill
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.widthAnchor.constraint(equalToConstant: 96).isActive = true
        avatarButton.heightAnchor.constraint(equalToConstant: 96).isActive = true
        avatarButton.addTarget(self, action: #selector(onPickAvatar), for: .touchUpInside)

        let changePhotoLabel = UILabel()
        changePhotoLabel.text = "Toca para cambiar la foto"
        changePhotoLabel.font = .systemFont(ofSize: 12)
        changePhotoLabel.textColor = .secondaryLabel

        usernameLabel.font = .boldSystemFont(ofSize: 20)
        usernameLabel.isUserInteractionEnabled = true
        usernameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onRenameTapped)))

        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel

        let privacyRow = tappableSwitchRow(
            icon: "lock", title: "Cuenta privada",
            subtitle: "Quien quiera seguirte necesitará que aceptes su solicitud", control: privacySwitch)
        privacySwitch.addTarget(self, action: #selector(onPrivacyChanged), for: .valueChanged)

        let ridesRow = tappableRow(icon: "clock.arrow.circlepath", title: "Mis rides", action: #selector(onRidesTapped))
        let logoutRow = tappableRow(
            icon: "rectangle.portrait.and.arrow.right", title: "Cerrar sesión",
            action: #selector(onLogoutTapped), destructive: true)

        let stack = UIStackView(arrangedSubviews: [
            avatarButton, changePhotoLabel, usernameLabel, emailLabel,
            spacer(24), privacyRow, divider(), ridesRow, divider(), logoutRow,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(20, after: emailLabel)
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            privacyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            ridesRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            logoutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func populate() {
        guard let user = AuthManager.shared.currentUser else { return }
        usernameLabel.text = user.username
        emailLabel.text = user.email
        privacySwitch.isOn = user.isPrivate
        avatarButton.setImage(UIImage(systemName: "person.circle.fill"), for: .normal)
        if let avatarUrl = user.avatarUrl, let url = RemoteImageView.resolvedURL(avatarUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.avatarButton.setImage(image, for: .normal) }
            }.resume()
        }
    }

    private func tappableRow(icon: String, title: String, action: Selector, destructive: Bool = false) -> UIView {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.title = title
        config.imagePadding = 12
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 4, bottom: 14, trailing: 4)
        config.titleAlignment = .leading
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.tintColor = destructive ? .systemRed : .label
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func tappableSwitchRow(icon: String, title: String, subtitle: String, control: UISwitch) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .label

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack, control])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    private func divider() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    @objc private func onPickAvatar() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func onRenameTapped() {
        let alert = UIAlertController(title: "Cambiar nombre", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = AuthManager.shared.currentUser?.username }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Guardar", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            Task {
                try? await AuthManager.shared.updateProfile(username: name)
                self?.populate()
            }
        })
        present(alert, animated: true)
    }

    @objc private func onPrivacyChanged() {
        Task { try? await AuthManager.shared.updateProfile(isPrivate: privacySwitch.isOn) }
    }

    @objc private func onRidesTapped() {
        navigationController?.pushViewController(RidesHistoryViewController(), animated: true)
    }

    @objc private func onLogoutTapped() {
        let alert = UIAlertController(
            title: "Cerrar sesión", message: "¿Seguro que quieres cerrar sesión?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cerrar sesión", style: .destructive) { _ in
            AuthManager.shared.logout()
            (UIApplication.shared.delegate as? AppDelegate)?.showLogin()
        })
        present(alert, animated: true)
    }
}

extension SettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            Task {
                guard let url = try? await UploadsRepository().uploadImage(image) else { return }
                try? await AuthManager.shared.updateProfile(avatarUrl: url)
                DispatchQueue.main.async { self?.populate() }
            }
        }
    }
}
