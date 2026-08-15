import UIKit

/// Fila compacta de "Últimas rutas" en el perfil — espejo de la fila
/// `prof.rides` del prototipo: miniatura de mapa pequeña + nombre + fecha,
/// mucho más ligera que la tarjeta grande de `RouteCardCell` (esa vive en
/// Rutas/Mis Rutas, aquí solo hace falta un vistazo rápido).
final class RiderRouteRowCell: UICollectionViewCell {
    private let card = UIView()
    private let mapImage = RemoteImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 13
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        mapImage.layer.cornerRadius = 9
        mapImage.clipsToBounds = true
        mapImage.backgroundColor = AppTheme.bg0
        mapImage.translatesAutoresizingMaskIntoConstraints = false
        mapImage.widthAnchor.constraint(equalToConstant: 64).isActive = true
        mapImage.heightAnchor.constraint(equalToConstant: 44).isActive = true

        nameLabel.font = AppFont.body(14.5, .semibold)
        nameLabel.textColor = AppTheme.text
        nameLabel.numberOfLines = 1

        metaLabel.styleAsLabel(size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        chevron.tintColor = AppTheme.textSecondary(0.4)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let row = UIStackView(arrangedSubviews: [mapImage, textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 11
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 9),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -9),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -11),
        ])
    }

    func configure(with route: RouteSummary) {
        nameLabel.text = route.name
        let km = String(format: "%.1f", route.distanceKm)
        metaLabel.styleAsLabel(
            "\(km) km · \(Self.dateFormatter.string(from: route.createdAt))",
            size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        let snapshotURL = RouteMapSnapshot.url(for: route.path, width: 160, height: 110)
        mapImage.load(urlString: snapshotURL?.absoluteString ?? route.coverImageUrl, placeholder: UIImage(systemName: "map"))
    }
}
