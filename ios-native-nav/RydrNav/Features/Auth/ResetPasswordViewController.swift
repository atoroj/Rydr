import UIKit

/// Segundo paso de "¿Olvidaste tu contraseña?" — código de 6 dígitos +
/// contraseña nueva. Al terminar, vuelve a `LoginViewController` (no
/// deja la sesión iniciada: el backend no devuelve token al resetear,
/// solo confirma el cambio, así que hay que entrar a mano con la
/// contraseña nueva, igual que en el flujo por defecto de la mayoría de
/// apps).
final class ResetPasswordViewController: UIViewController {
    private let email: String

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let codeField = UITextField()
    private let passwordField = UITextField()
    private let confirmField = UITextField()
    private let confirmButton = UIButton(type: .system)
    private let resendButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var stackCenterYConstraint: NSLayoutConstraint!

    init(email: String) {
        self.email = email
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nueva contraseña"
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
        titleLabel.text = "Revisa tu correo"
        titleLabel.font = AppFont.body(20, .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center

        subtitleLabel.text = "Te hemos mandado un código de 6 dígitos a \(email). Caduca en 15 minutos."
        subtitleLabel.font = AppFont.body(14)
        subtitleLabel.textColor = AppTheme.textSecondary(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        codeField.placeholder = "Código de 6 dígitos"
        stylePillField(codeField)
        codeField.keyboardType = .numberPad
        codeField.textAlignment = .center
        codeField.returnKeyType = .next
        codeField.delegate = self

        passwordField.placeholder = "Contraseña nueva (mínimo 6 caracteres)"
        stylePillField(passwordField)
        passwordField.isSecureTextEntry = true
        passwordField.returnKeyType = .next
        passwordField.delegate = self

        confirmField.placeholder = "Repite la contraseña"
        stylePillField(confirmField)
        confirmField.isSecureTextEntry = true
        confirmField.returnKeyType = .go
        confirmField.delegate = self

        confirmButton.setTitle("Cambiar contraseña", for: .normal)
        confirmButton.titleLabel?.font = AppFont.body(17, .bold)
        confirmButton.backgroundColor = AppTheme.primary
        confirmButton.setTitleColor(AppTheme.bg0, for: .normal)
        confirmButton.layer.cornerRadius = 8
        confirmButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        confirmButton.addTarget(self, action: #selector(onConfirmTapped), for: .touchUpInside)

        resendButton.setTitle("¿No te ha llegado? Reenviar código", for: .normal)
        resendButton.titleLabel?.font = AppFont.body(14)
        resendButton.setTitleColor(AppTheme.textSecondary(0.7), for: .normal)
        resendButton.addTarget(self, action: #selector(onResendTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, spacer(8), subtitleLabel, spacer(28), codeField, spacer(16), passwordField,
            spacer(16), confirmField, spacer(24), confirmButton, spinner, spacer(16), resendButton,
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

    private func stylePillField(_ field: UITextField) {
        field.borderStyle = .roundedRect
        field.backgroundColor = AppTheme.bg2
        field.textColor = AppTheme.text
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    @objc private func onResendTapped() {
        resendButton.isEnabled = false
        Task {
            try? await AuthManager.shared.requestPasswordReset(email: email)
            await MainActor.run {
                self.resendButton.isEnabled = true
                self.showAlert(title: "Código reenviado", message: "Si el email existe, te llegará un código nuevo.")
            }
        }
    }

    @objc private func onConfirmTapped() {
        guard let code = codeField.text, code.count == 6 else {
            showAlert(title: "Revisa el código", message: "El código tiene 6 dígitos.")
            return
        }
        guard let password = passwordField.text, password.count >= 6 else {
            showAlert(title: "Contraseña muy corta", message: "Al menos 6 caracteres.")
            return
        }
        guard password == confirmField.text else {
            showAlert(title: "Las contraseñas no coinciden", message: "Escribe la misma contraseña en los dos campos.")
            return
        }

        confirmButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                try await AuthManager.shared.resetPassword(email: email, code: code, newPassword: password)
                await MainActor.run {
                    self.showAlert(title: "Contraseña cambiada", message: "Ya puedes entrar con tu contraseña nueva.")
                    self.navigationController?.popToRootViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.confirmButton.isEnabled = true
                    self.spinner.stopAnimating()
                    self.showAlert(title: "No se pudo cambiar", message: "El código no es correcto o ha caducado.")
                }
            }
        }
    }
}

extension ResetPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === codeField {
            passwordField.becomeFirstResponder()
        } else if textField === passwordField {
            confirmField.becomeFirstResponder()
        } else {
            view.endEditing(true)
            onConfirmTapped()
        }
        return true
    }
}
