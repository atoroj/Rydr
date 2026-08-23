import UIKit

/// Tarjeta del feed de portada — espejo 1:1 de la tarjeta `is.feed` del
/// prototipo de Claude Design: cabecera (avatar + nombre + "hace X" +
/// insignia de moto) → título → mapa real con el trazado en ámbar → grid
/// de 3 columnas con separadores → enlace de cierre "Hacer esta ruta →".
/// (El prototipo añade ahí un contador de "me gusta"/comentarios; eso es
/// una función social nueva que no existe en el backend, así que se deja
/// fuera — ver plan de rediseño.)
final class FeedItemCell: UICollectionViewCell {
    var onAuthorTapped: (() -> Void)?
    var onOpenTapped: (() -> Void)?

    private let card = UIView()
    private let openButton = UIButton(type: .system)
    private let authorAvatar = RemoteImageView()
    private let authorNameLabel = UILabel()
    private let metaLabel = UILabel()
    private let bikeBadge = UILabel()
    private let titleLabel = UILabel()
    private let mapImage = RemoteImageView()
    private let statsRow = UIStackView()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.unitsStyle = .short
        return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = AppTheme.cardRadius
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Toda la tarjeta abre la ruta; el botón del autor (encima) se lleva
        // el toque en su zona para poder abrir el perfil en su lugar.
        openButton.addTarget(self, action: #selector(onTapOpen), for: .touchUpInside)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        authorAvatar.layer.cornerRadius = 17
        authorAvatar.translatesAutoresizingMaskIntoConstraints = false
        authorAvatar.widthAnchor.constraint(equalToConstant: 34).isActive = true
        authorAvatar.heightAnchor.constraint(equalToConstant: 34).isActive = true

        authorNameLabel.font = AppFont.body(14.5, .semibold)
        authorNameLabel.textColor = AppTheme.text

        metaLabel.styleAsLabel(size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let authorTextStack = UIStackView(arrangedSubviews: [authorNameLabel, metaLabel])
        authorTextStack.axis = .vertical
        authorTextStack.spacing = 1

        bikeBadge.layer.cornerRadius = 6
        bikeBadge.layer.borderWidth = 1
        bikeBadge.layer.borderColor = AppTheme.cardBorder.cgColor
        bikeBadge.clipsToBounds = true
        bikeBadge.textAlignment = .center

        let authorButton = UIButton(type: .system)
        authorButton.addTarget(self, action: #selector(onTapAuthor), for: .touchUpInside)
        authorButton.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView(arrangedSubviews: [authorAvatar, authorTextStack, bikeBadge])
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .center
        headerRow.isUserInteractionEnabled = false
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppFont.body(17, .semibold)
        titleLabel.textColor = AppTheme.text
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        mapImage.backgroundColor = AppTheme.bg0
        mapImage.translatesAutoresizingMaskIntoConstraints = false

        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.translatesAutoresizingMaskIntoConstraints = false

        let footerLabel = UILabel()
        footerLabel.styleAsLabel("Hacer esta ruta →", size: 11, medium: false, color: AppTheme.primary, tracking: 0.9)
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        let footerRow = UIView()
        // Sin esto, footerRow (una UIView normal, interactiva por
        // defecto) se quedaba con el toque antes de que llegara a
        // openButton, que está detrás de todo — el enlace "Hacer esta
        // ruta →" no hacía nada al pulsarlo.
        footerRow.isUserInteractionEnabled = false
        footerRow.translatesAutoresizingMaskIntoConstraints = false
        footerRow.addSubview(footerLabel)
        NSLayoutConstraint.activate([
            footerLabel.leadingAnchor.constraint(equalTo: footerRow.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: footerRow.trailingAnchor),
            footerLabel.topAnchor.constraint(equalTo: footerRow.topAnchor, constant: 10),
            footerLabel.bottomAnchor.constraint(equalTo: footerRow.bottomAnchor, constant: -12),
        ])

        let dividerAboveStats = hairline()
        let dividerAboveFooter = hairline()

        card.addSubview(headerRow)
        card.addSubview(titleLabel)
        card.addSubview(mapImage)
        card.addSubview(dividerAboveStats)
        card.addSubview(statsRow)
        card.addSubview(dividerAboveFooter)
        card.addSubview(footerRow)
        card.addSubview(authorButton)
        card.addSubview(openButton)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            headerRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            headerRow.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -13),

            authorButton.topAnchor.constraint(equalTo: headerRow.topAnchor),
            authorButton.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            authorButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            authorButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),

            mapImage.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            mapImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            mapImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            mapImage.heightAnchor.constraint(equalToConstant: 168),

            dividerAboveStats.topAnchor.constraint(equalTo: mapImage.bottomAnchor),
            dividerAboveStats.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            dividerAboveStats.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            statsRow.topAnchor.constraint(equalTo: dividerAboveStats.bottomAnchor),
            statsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            statsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            dividerAboveFooter.topAnchor.constraint(equalTo: statsRow.bottomAnchor),
            dividerAboveFooter.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            dividerAboveFooter.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            footerRow.topAnchor.constraint(equalTo: dividerAboveFooter.bottomAnchor),
            footerRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            footerRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
            footerRow.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            openButton.topAnchor.constraint(equalTo: card.topAnchor),
            openButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            openButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            openButton.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        // El botón de "abrir" ocupa toda la tarjeta pero por debajo (se
        // añadió primero); el de autor, encima suyo, le roba el toque solo
        // en la franja de la cabecera.
        card.sendSubviewToBack(openButton)
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = AppTheme.cardBorder
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func statCell(value: String, unit: String, showsLeadingDivider: Bool) -> UIView {
        let container = UIView()
        // Mismo motivo que en footerRow: es solo un contenedor visual, no
        // debe robarle el toque a openButton.
        container.isUserInteractionEnabled = false
        if showsLeadingDivider {
            let divider = UIView()
            divider.backgroundColor = AppTheme.cardBorder
            divider.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(divider)
            NSLayoutConstraint.activate([
                divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                divider.topAnchor.constraint(equalTo: container.topAnchor),
                divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                divider.widthAnchor.constraint(equalToConstant: 1),
            ])
        }

        let valueLabel = UILabel()
        valueLabel.attributedText = NSAttributedString(string: value, attributes: [
            .font: AppFont.data(22), .foregroundColor: AppTheme.text,
        ])
        let unitLabel = UILabel()
        unitLabel.styleAsLabel(unit, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)

        let stack = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 13),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -11),
        ])
        return container
    }

    func configure(with item: FeedItem) {
        authorNameLabel.text = item.author.username
        authorAvatar.loadAvatar(urlString: item.author.avatarUrl, displayName: item.author.username)
        metaLabel.styleAsLabel(
            Self.relativeFormatter.localizedString(for: item.route.createdAt, relativeTo: Date()),
            size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        if let bike = item.author.currentMotorbike {
            bikeBadge.isHidden = false
            bikeBadge.styleAsLabel(" \(bike.displayName) ", size: 10.5, color: AppTheme.textSecondary(0.55), tracking: 0.7)
        } else {
            bikeBadge.isHidden = true
        }

        titleLabel.text = item.route.name

        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let values = [("\(item.route.distanceKm)", "KM"), ("\(item.route.durationMinutes)", "MIN")]
        for (index, value) in values.enumerated() {
            statsRow.addArrangedSubview(statCell(value: value.0, unit: value.1, showsLeadingDivider: index > 0))
        }

        let snapshotURL = RouteMapSnapshot.url(for: item.route.segments)
        mapImage.load(
            urlString: snapshotURL?.absoluteString ?? item.route.coverImageUrl,
            placeholder: UIImage(systemName: "map"))
    }

    @objc private func onTapAuthor() { onAuthorTapped?() }
    @objc private func onTapOpen() { onOpenTapped?() }
}
