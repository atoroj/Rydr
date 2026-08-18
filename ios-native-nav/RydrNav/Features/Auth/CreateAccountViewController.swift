import UIKit

/// Registro propio (usuario/email/contraseña) — mismo aire visual que
/// `LoginViewController`, empujada desde ahí ("¿No tienes cuenta? Crea
/// una"). No lleva botón de Google: esa vía ya crea el perfil ella sola
/// la primera vez que se usa, no hace falta duplicarla aquí.
final class CreateAccountViewController: UIViewController {
    private let logoView = RydrLogoView()
    private let wordmarkLabel = UILabel()
    private let usernameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let createButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var stackCenterYConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Crear cuenta"
        view.backgroundColor = AppTheme.bg0
        setupUI()

        // Mismo motivo que en LoginViewController: sin esto, el teclado
        // tapa el botón "Crear cuenta" en un teléfono físico.
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
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        wordmarkLabel.attributedText = NSAttributedString(string: "RYDR", attributes: [
            .font: AppFont.data(30), .foregroundColor: AppTheme.text, .kern: 4,
        ])
        wordmarkLabel.textAlignment = .center

        let logoStack = UIStackView(arrangedSubviews: [logoView, wordmarkLabel])
        logoStack.axis = .vertical
        logoStack.spacing = 10
        logoStack.alignment = .center

        usernameField.placeholder = "Usuario"
        stylePillField(usernameField)
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.returnKeyType = .next
        usernameField.delegate = self

        emailField.placeholder = "Email"
        stylePillField(emailField)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .next
        emailField.delegate = self

        passwordField.placeholder = "Contraseña (mínimo 6 caracteres)"
        stylePillField(passwordField)
        passwordField.isSecureTextEntry = true
        passwordField.returnKeyType = .go
        passwordField.delegate = self

        createButton.setTitle("Crear cuenta", for: .normal)
        createButton.titleLabel?.font = AppFont.body(17, .bold)
        createButton.backgroundColor = AppTheme.primary
        createButton.setTitleColor(AppTheme.bg0, for: .normal)
        createButton.layer.cornerRadius = 8
        createButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        createButton.addTarget(self, action: #selector(onCreateTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            logoStack, spacer(48), usernameField, spacer(16), emailField, spacer(16), passwordField,
            spacer(32), createButton, spinner,
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

    @objc private func onCreateTapped() {
        let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !username.isEmpty,
              let email = emailField.text, email.contains("@"),
              let password = passwordField.text, password.count >= 6
        else {
            showAlert(title: "Revisa los datos", message: "Usuario, email válido y contraseña de al menos 6 caracteres.")
            return
        }

        createButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                try await AuthManager.shared.createAccount(username: username, email: email, password: password)
                await MainActor.run {
                    (UIApplication.shared.delegate as? AppDelegate)?.showMain()
                }
            } catch {
                await MainActor.run {
                    self.createButton.isEnabled = true
                    self.spinner.stopAnimating()
                    self.showAlert(title: "No se pudo crear la cuenta", message: error.localizedDescription)
                }
            }
        }
    }
}

extension CreateAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === usernameField {
            emailField.becomeFirstResponder()
        } else if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            view.endEditing(true)
            onCreateTapped()
        }
        return true
    }
}
