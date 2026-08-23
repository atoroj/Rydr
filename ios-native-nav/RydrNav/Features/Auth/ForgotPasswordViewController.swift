import UIKit

/// Primer paso de "¿Olvidaste tu contraseña?" — solo pide el email y
/// dispara el envío del código de 6 dígitos. Nunca dice si ese email
/// existe o no en el sistema (el backend tampoco lo dice, ver
/// `AuthRepository.requestPasswordReset`) — el mensaje es el mismo pase
/// lo que pase, y siempre se avanza a `ResetPasswordViewController`.
final class ForgotPasswordViewController: UIViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emailField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var stackCenterYConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recuperar contraseña"
        view.backgroundColor = AppTheme.bg0
        setupUI()

        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(onBackgroundTapped))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onBackgroundTapped() {
        view.endEditing(true)
    }

    @objc private func onKeyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let durationNumber = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curveNumber = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        else { return }

        let keyboardFrameInView = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.origin.y)
        stackCenterYConstraint.constant = overlap > 0 ? -(overlap / 2) : 0

        let options = UIView.AnimationOptions(rawValue: curveNumber.uintValue << 16)
        UIView.animate(withDuration: durationNumber.doubleValue, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    private func setupUI() {
        titleLabel.text = "¿Olvidaste tu contraseña?"
        titleLabel.font = AppFont.body(20, .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Escribe tu email y te mandamos un código para elegir una nueva."
        subtitleLabel.font = AppFont.body(14)
        subtitleLabel.textColor = AppTheme.textSecondary(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.backgroundColor = AppTheme.bg2
        emailField.textColor = AppTheme.text
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .go
        emailField.delegate = self

        sendButton.setTitle("Enviar código", for: .normal)
        sendButton.titleLabel?.font = AppFont.body(17, .bold)
        sendButton.backgroundColor = AppTheme.primary
        sendButton.setTitleColor(AppTheme.bg0, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        sendButton.addTarget(self, action: #selector(onSendTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, spacer(8), subtitleLabel, spacer(32), emailField, spacer(24), sendButton, spinner,
        ])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        stackCenterYConstraint = stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackCenterYConstraint,
        ])
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    @objc private func onSendTapped() {
        guard let email = emailField.text, email.contains("@") else {
            showAlert(title: "Revisa el email", message: "Escribe un email válido.")
            return
        }

        sendButton.isEnabled = false
        spinner.startAnimating()

        Task {
            // No hace falta comprobar el resultado: el backend siempre
            // responde 204 exista o no ese email, así que un fallo real
            // aquí sería de red, no de "email no encontrado".
            try? await AuthManager.shared.requestPasswordReset(email: email)
            await MainActor.run {
                self.sendButton.isEnabled = true
                self.spinner.stopAnimating()
                self.navigationController?.pushViewController(
                    ResetPasswordViewController(email: email), animated: true)
            }
        }
    }
}

extension ForgotPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        onSendTapped()
        return true
    }
}
