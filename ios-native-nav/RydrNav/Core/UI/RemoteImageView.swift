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

    /// Como `load(urlString:placeholder:)`, pero para avatares de persona:
    /// si no hay foto (o falla la descarga), en vez del icono genérico de
    /// `person.circle.fill` de antes, dibuja las iniciales de [displayName]
    /// en ámbar — "Pepe Dominguez" → "PD". Único punto donde se genera ese
    /// placeholder, para que todos los avatares de la app (feed, riders,
    /// perfil, ajustes, quedadas...) se vean igual.
    func loadAvatar(urlString: String?, displayName: String) {
        load(urlString: urlString, placeholder: Self.initialsAvatar(for: displayName))
    }

    /// Genera el placeholder de iniciales a un tamaño de referencia grande
    /// (se ve nítido al reescalarlo hacia abajo a cualquier tamaño de
    /// avatar de la app, de 28pt a 96pt) — degradado cálido→frío y letras
    /// en `AppTheme.primary`, con la tipografía Barlow del resto del
    /// sistema visual (antes esto solo lo tenía la top bar, y con una sola
    /// inicial).
    static func initialsAvatar(for displayName: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [UIColor(hex: 0x3A2A22).cgColor, UIColor(hex: 0x1B1E23).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            let text = initials(for: displayName)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: AppFont.body(size.height * 0.36, .semibold), .foregroundColor: AppTheme.primary,
            ]
            let textSize = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attrs)
        }
    }

    /// "Pepe Dominguez" → "PD" (inicial del nombre + inicial del primer
    /// apellido); si solo hay una palabra, se queda con esa única letra.
    /// Se separa solo por espacios — un "username" tipo `pablo_bmw` (los
    /// perfiles de prueba) no se trocea por el guion bajo, para no sacar
    /// iniciales sin sentido de ahí.
    static func initials(for displayName: String) -> String {
        let words = displayName.split(separator: " ").filter { !$0.isEmpty }
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let second = words[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }
}
