import UIKit

/// Espejo de lib/features/auth/presentation/login_screen.dart.
final class LoginViewController: UIViewController {
    private let logoView = RydrLogoView()
    private let wordmarkLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var stackCenterYConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupUI()

        // Sin esto, en un teléfono físico (donde el teclado ocupa buena
        // parte de la pantalla) el botón "Entrar" quedaba tapado detrás
        // del teclado al escribir la contraseña — no había manera de
        // tocarlo. Se sube el bloque cuando el teclado cubre parte suya.
        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)

        // Toca fuera de los campos para ocultar el teclado (con
        // `cancelsTouchesInView = false` para no robarle el toque al
        // propio botón "Entrar" cuando está debajo del dedo).
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

        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.backgroundColor = AppTheme.bg2
        emailField.textColor = AppTheme.text
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .next
        emailField.delegate = self

        passwordField.placeholder = "Contraseña"
        passwordField.borderStyle = .roundedRect
        passwordField.backgroundColor = AppTheme.bg2
        passwordField.textColor = AppTheme.text
        passwordField.isSecureTextEntry = true
        // Antes no había forma de confirmar sin tocar "Entrar" — con el
        // teclado tapando el botón en un teléfono físico, eso lo dejaba
        // atascado. Con esto, Return en el campo de contraseña envía.
        passwordField.returnKeyType = .go
        passwordField.delegate = self

        loginButton.setTitle("Entrar", for: .normal)
        loginButton.titleLabel?.font = AppFont.body(17, .bold)
        loginButton.backgroundColor = AppTheme.primary
        loginButton.setTitleColor(AppTheme.bg0, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        loginButton.addTarget(self, action: #selector(onLoginTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            logoStack, spacer(48), emailField, spacer(16), passwordField, spacer(32),
            loginButton, spinner,
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

    @objc private func onLoginTapped() {
        guard let email = emailField.text, email.contains("@"),
              let password = passwordField.text, password.count >= 2
        else {
            showError("Revisa el email y la contraseña.")
            return
        }

        loginButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                try await AuthManager.shared.login(email: email, password: password)
                await MainActor.run {
                    (UIApplication.shared.delegate as? AppDelegate)?.showMain()
                }
            } catch {
                await MainActor.run {
                    self.loginButton.isEnabled = true
                    self.spinner.stopAnimating()
                    self.showError("Email o contraseña incorrectos")
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "No se pudo entrar", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            view.endEditing(true)
            onLoginTapped()
        }
        return true
    }
}
