import UIKit

/// Alerta genérica de una sola acción ("OK") — antes cada pantalla tenía
/// su propia copia casi idéntica de esto (`showAlert`/`showError`, mismo
/// cuerpo en las seis). `title` por defecto "Vaya", el que ya usaba la
/// mayoría; las pantallas que necesitaban un título distinto lo siguen
/// pasando explícito.
extension UIViewController {
    func showAlert(title: String = "Vaya", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
