import PhotosUI
import UIKit

/// Ajustes: avatar, nombre, cuenta privada, acceso al historial de rides y
/// cerrar sesión. Abierta desde el engranaje de la top bar — distinta del
/// perfil social (que se abre pulsando el avatar): aquí vive la gestión de
/// la cuenta, allí el escaparate público del rider. Espejo de
/// lib/features/settings/presentation/settings_screen.dart.
final class SettingsViewController: UIViewController {
    private let avatarButton = UIButton(type: .system)
    private let avatarSpinner = UIActivityIndicatorView(style: .medium)
    private let usernameLabel = UILabel()
    private let emailLabel = UILabel()
    private let privacySwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ajustes"
        view.backgroundColor = AppTheme.bg0
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

        avatarSpinner.color = AppTheme.primary
        avatarSpinner.hidesWhenStopped = true
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarSpinner.isUserInteractionEnabled = false
        avatarButton.addSubview(avatarSpinner)
        NSLayoutConstraint.activate([
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarButton.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarButton.centerYAnchor),
        ])

        let changePhotoLabel = UILabel()
        changePhotoLabel.text = "Toca para cambiar la foto"
        changePhotoLabel.font = AppFont.body(12)
        changePhotoLabel.textColor = AppTheme.textSecondary(0.5)

        usernameLabel.font = AppFont.body(20, .bold)
        usernameLabel.textColor = AppTheme.text
        usernameLabel.isUserInteractionEnabled = true
        usernameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onRenameTapped)))

        emailLabel.font = AppFont.body(14)
        emailLabel.textColor = AppTheme.textSecondary(0.5)

        let privacyRow = tappableSwitchRow(
            icon: "lock", title: "Cuenta privada",
            subtitle: "Quien quiera seguirte necesitará que aceptes su solicitud", control: privacySwitch)
        privacySwitch.addTarget(self, action: #selector(onPrivacyChanged), for: .valueChanged)

        let ridesRow = tappableRow(icon: "clock.arrow.circlepath", title: "Mis rides", action: #selector(onRidesTapped))
        let offlineMapsRow = tappableRow(
            icon: "arrow.down.circle", title: "Mapas sin conexión", action: #selector(onOfflineMapsTapped))
        let logoutRow = tappableRow(
            icon: "rectangle.portrait.and.arrow.right", title: "Cerrar sesión",
            action: #selector(onLogoutTapped), destructive: true)

        let stack = UIStackView(arrangedSubviews: [
            avatarButton, changePhotoLabel, usernameLabel, emailLabel,
            spacer(24), privacyRow, divider(), ridesRow, divider(), offlineMapsRow, divider(), logoutRow,
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
            offlineMapsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            logoutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func populate() {
        guard let user = AuthManager.shared.currentUser else { return }
        usernameLabel.text = user.username
        emailLabel.text = user.email
        privacySwitch.isOn = user.isPrivate
        // Tamaño exacto del botón — a diferencia de un UIImageView normal,
        // UIButton.setImage no escala la imagen a su propio tamaño.
        // `.alwaysOriginal`: sin esto, un UIButton(type: .system) trata la
        // imagen como plantilla y la tiñe entera con `tintColor` (el
        // ámbar de marca) — tanto esta como la foto real de perfil se
        // veían como un círculo ámbar liso, sin ningún detalle propio.
        avatarButton.setImage(
            RemoteImageView.initialsAvatar(for: user.username, size: CGSize(width: 96, height: 96))
                .withRenderingMode(.alwaysOriginal),
            for: .normal)
        if let avatarUrl = user.avatarUrl, let url = RemoteImageView.resolvedURL(avatarUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.avatarButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal) }
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
        button.tintColor = destructive ? .systemRed : AppTheme.text
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func tappableSwitchRow(icon: String, title: String, subtitle: String, control: UISwitch) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppTheme.text

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.body(16)
        titleLabel.textColor = AppTheme.text

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = AppFont.body(12)
        subtitleLabel.textColor = AppTheme.textSecondary(0.5)
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
        v.backgroundColor = AppTheme.cardBorder
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

    @objc private func onOfflineMapsTapped() {
        navigationController?.pushViewController(OfflineMapsViewController(), animated: true)
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

        avatarSpinner.startAnimating()
        avatarButton.isEnabled = false

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self else { return }
            guard let image = object as? UIImage else {
                // Antes se ignoraba en silencio: si esto fallaba (formato
                // no soportado, HEIC corrupto...) no pasaba nada visible y
                // parecía que la app "no dejaba" cambiar la foto.
                DispatchQueue.main.async {
                    self.avatarSpinner.stopAnimating()
                    self.avatarButton.isEnabled = true
                    self.showError("No se pudo leer la foto elegida\(error.map { ": \($0.localizedDescription)" } ?? ".")")
                }
                return
            }
            Task {
                do {
                    let url = try await UploadsRepository().uploadImage(image)
                    try await AuthManager.shared.updateProfile(avatarUrl: url)
                    await MainActor.run {
                        self.avatarSpinner.stopAnimating()
                        self.avatarButton.isEnabled = true
                        self.populate()
                    }
                } catch {
                    // Antes, tanto la subida como la actualización de
                    // perfil iban con `try?`: si cualquiera de las dos
                    // fallaba (sin red, IP de desarrollo desactualizada,
                    // token caducado...) no se avisaba de nada.
                    await MainActor.run {
                        self.avatarSpinner.stopAnimating()
                        self.avatarButton.isEnabled = true
                        self.showError("No se pudo actualizar la foto de perfil: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Vaya", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
