import UIKit

/// Tarjeta del feed de portada: quién hizo la ruta (avatar + nombre) y la
/// ruta en sí (mapa con el trazado + nombre + estadísticas), igual que las
/// tarjetas de Rutas/Mis Rutas pero con la cabecera de autor encima.
final class FeedItemCell: UICollectionViewCell {
    var onAuthorTapped: (() -> Void)?

    private let card = UIView()
    private let authorAvatar = RemoteImageView()
    private let authorLabel = UILabel()
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

        authorAvatar.layer.cornerRadius = 16
        authorAvatar.translatesAutoresizingMaskIntoConstraints = false
        authorAvatar.widthAnchor.constraint(equalToConstant: 32).isActive = true
        authorAvatar.heightAnchor.constraint(equalToConstant: 32).isActive = true

        authorLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let authorButton = UIButton(type: .system)
        authorButton.addTarget(self, action: #selector(onTapAuthor), for: .touchUpInside)
        authorButton.translatesAutoresizingMaskIntoConstraints = false

        let authorRow = UIStackView(arrangedSubviews: [authorAvatar, authorLabel])
        authorRow.axis = .horizontal
        authorRow.spacing = 8
        authorRow.alignment = .center
        authorRow.isUserInteractionEnabled = false // el UIButton de encima recoge el toque
        authorRow.translatesAutoresizingMaskIntoConstraints = false

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

        card.addSubview(authorRow)
        card.addSubview(authorButton)
        card.addSubview(coverImage)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            authorRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            authorRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            authorRow.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),

            authorButton.topAnchor.constraint(equalTo: authorRow.topAnchor),
            authorButton.bottomAnchor.constraint(equalTo: authorRow.bottomAnchor),
            authorButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            authorButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            coverImage.topAnchor.constraint(equalTo: authorRow.bottomAnchor, constant: 12),
            coverImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImage.heightAnchor.constraint(equalToConstant: 140),

            textStack.topAnchor.constraint(equalTo: coverImage.bottomAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
    }

    func configure(with item: FeedItem) {
        authorLabel.text = item.author.username
        authorAvatar.load(urlString: item.author.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))

        nameLabel.text = item.route.name
        statsLabel.text = "\(item.route.distanceKm) km · \(item.route.durationMinutes) min"

        let snapshotURL = RouteMapSnapshot.url(for: item.route.path)
        coverImage.load(
            urlString: snapshotURL?.absoluteString ?? item.route.coverImageUrl,
            placeholder: UIImage(systemName: "map"))
    }

    @objc private func onTapAuthor() { onAuthorTapped?() }
}
