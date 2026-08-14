import UIKit

/// Espejo de lib/features/auth/presentation/login_screen.dart.
final class LoginViewController: UIViewController {
    private let logoLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        logoLabel.text = "🏍️ Rydr"
        logoLabel.font = .systemFont(ofSize: 34, weight: .bold)
        logoLabel.textAlignment = .center

        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no

        passwordField.placeholder = "Contraseña"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true

        loginButton.setTitle("Entrar", for: .normal)
        loginButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        loginButton.backgroundColor = AppTheme.primary
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        loginButton.addTarget(self, action: #selector(onLoginTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            logoLabel, spacer(48), emailField, spacer(16), passwordField, spacer(32),
            loginButton, spinner,
        ])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
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
