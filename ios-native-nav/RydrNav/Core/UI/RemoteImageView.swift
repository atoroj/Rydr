import UIKit

/// `UIImageView` que carga una imagen remota del backend (avatar, foto de
/// moto, portada de ruta) — equivalente nativo de `NetworkAvatar`/
/// `CoverImage` (lib/core/widgets). Resuelve rutas relativas (`/uploads/...`)
/// contra `APIConstants.baseURL` y cachea en memoria para no repetir
/// descargas al hacer scroll en una `UICollectionView`/`UITableView`.
final class RemoteImageView: UIImageView {
    private static let cache = NSCache<NSString, UIImage>()

    private var currentURLString: String?

    /// Carga [urlString] (relativa o absoluta) o, si es `nil`/vacía, deja
    /// [placeholder]. Cancela silenciosamente si la vista se reutiliza para
    /// otra URL antes de que termine la descarga (celdas recicladas).
    func load(urlString: String?, placeholder: UIImage?) {
        currentURLString = urlString
        image = placeholder
        contentMode = .scaleAspectFill
        clipsToBounds = true

        guard let urlString, !urlString.isEmpty,
              let url = Self.resolvedURL(urlString)
        else { return }

        if let cached = Self.cache.object(forKey: urlString as NSString) {
            image = cached
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let downloaded = UIImage(data: data) else { return }
            Self.cache.setObject(downloaded, forKey: urlString as NSString)
            DispatchQueue.main.async {
                // Si mientras tanto la celda se recicló para otra URL, no
                // pisamos la imagen que le corresponde ahora.
                guard self?.currentURLString == urlString else { return }
                self?.image = downloaded
            }
        }.resume()
    }

    /// Resuelve una URL relativa (`/uploads/...`) o absoluta a una `URL`
    /// completa contra `APIConstants.baseURL`. Expuesto para quien necesite
    /// descargar una imagen sin pasar por esta vista (p.ej. el avatar de la
    /// top bar, que vive en un `UIBarButtonItem` sin `RemoteImageView`).
    static func resolvedURL(_ urlString: String) -> URL? {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        return URL(string: APIConstants.baseURL.absoluteString + urlString)
    }
}
