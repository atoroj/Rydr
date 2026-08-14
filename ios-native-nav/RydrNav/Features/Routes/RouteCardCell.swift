import UIKit

/// Tarjeta de ruta con miniatura — el spec pide "formato tarjeta con una
/// imagen en miniatura", así que esto sustituye a la fila de
/// `UITableView` con subtítulo que había antes. Reutilizada por Rutas,
/// Mis Rutas y el feed de últimas rutas del perfil de un Rider.
final class RouteCardCell: UICollectionViewCell {
    private let card = UIView()
    private let coverImage = RemoteImageView()
    private let nameLabel = UILabel()
    private let statsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        coverImage.backgroundColor = .tertiarySystemBackground
        coverImage.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .boldSystemFont(ofSize: 17)
        nameLabel.numberOfLines = 2

        statsLabel.font = .systemFont(ofSize: 13)
        statsLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [nameLabel, statsLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(coverImage)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            coverImage.topAnchor.constraint(equalTo: card.topAnchor),
            coverImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImage.heightAnchor.constraint(equalToConstant: 140),

            textStack.topAnchor.constraint(equalTo: coverImage.bottomAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
    }

    func configure(with route: RouteModel) {
        nameLabel.text = route.name
        statsLabel.text = "\(route.distanceKm) km · \(route.durationMinutes) min · \(route.timesRidden) veces"
        // Miniatura = mapa generado con el trazado real, no la foto de
        // portada subida al publicar (esa se enseña en el detalle de la
        // ruta). Si por lo que sea no se puede generar (sin puntos, sin
        // token...) cae a la foto subida y, si tampoco hay, al placeholder.
        let snapshotURL = RouteMapSnapshot.url(for: route.path)
        coverImage.load(urlString: snapshotURL?.absoluteString ?? route.coverImageUrl, placeholder: UIImage(systemName: "map"))
    }
}
