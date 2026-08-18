import UIKit

/// Tarjeta de ruta — espejo de la tarjeta `is.routes` del prototipo de
/// Claude Design: mapa real arriba (con el trazado en ámbar), título,
/// línea de "veces recorrida" y fila de cifras. Reutilizada por Rutas,
/// Mis Rutas y el feed de últimas rutas del perfil de un Rider.
/// (El prototipo superpone insignias de "región"/"curvas" sobre el mapa;
/// esos datos no existen en el backend, así que se dejan fuera.)
final class RouteCardCell: UICollectionViewCell {
    private let card = UIView()
    private let coverImage = RemoteImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let statsRow = UIStackView()

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

        coverImage.backgroundColor = AppTheme.bg0
        coverImage.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = AppFont.body(17, .semibold)
        nameLabel.textColor = AppTheme.text
        nameLabel.numberOfLines = 2

        metaLabel.styleAsLabel(size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        statsRow.axis = .horizontal
        statsRow.spacing = 22
        statsRow.translatesAutoresizingMaskIntoConstraints = false

        // `statsRow` fuera de `textStack` a propósito: dentro, la
        // alineación `.fill` (por defecto en un UIStackView vertical) lo
        // estiraba a todo el ancho de la tarjeta, y como su distribución
        // interna es `.fill` también, ese ancho de más se lo quedaba
        // "MIN" empujándolo al borde derecho mientras "KM" se quedaba
        // pegado a la izquierda — con un hueco muerto en medio. Puesto
        // aparte, con su propio ancho natural anclado al borde derecho,
        // los dos grupos quedan juntos como se pide.
        let textStack = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(coverImage)
        card.addSubview(textStack)
        card.addSubview(statsRow)
        NSLayoutConstraint.activate([
            coverImage.topAnchor.constraint(equalTo: card.topAnchor),
            coverImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImage.heightAnchor.constraint(equalToConstant: 132),

            textStack.topAnchor.constraint(equalTo: coverImage.bottomAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -13),

            statsRow.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 11),
            statsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
            statsRow.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 13),
            statsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
    }

    func configure(with route: RouteModel) {
        nameLabel.text = route.name
        metaLabel.styleAsLabel(
            route.timesRidden == 1 ? "1 rider la ha hecho" : "\(route.timesRidden) riders la han hecho",
            size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        [("\(route.distanceKm)", "KM"), ("\(route.durationMinutes)", "MIN")]
            .forEach { statsRow.addArrangedSubview(RouteCardCell.statView(value: $0.0, unit: $0.1)) }

        // Miniatura = mapa generado con el trazado real, no la foto de
        // portada subida al publicar (esa se enseña en el detalle de la
        // ruta). Si por lo que sea no se puede generar (sin puntos, sin
        // token...) cae a la foto subida y, si tampoco hay, al placeholder.
        let snapshotURL = RouteMapSnapshot.url(for: route.segments)
        coverImage.load(urlString: snapshotURL?.absoluteString ?? route.coverImageUrl, placeholder: UIImage(systemName: "map"))
    }

    static func statView(value: String, unit: String) -> UIView {
        let valueLabel = UILabel()
        valueLabel.attributedText = NSAttributedString(string: value, attributes: [
            .font: AppFont.data(20), .foregroundColor: AppTheme.text,
        ])
        let unitLabel = UILabel()
        unitLabel.attributedText = NSAttributedString(string: " \(unit)", attributes: [
            .font: AppFont.label(11), .foregroundColor: AppTheme.textSecondary(0.45), .kern: 0.6,
        ])
        let row = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        row.axis = .horizontal
        row.alignment = .lastBaseline
        row.spacing = 1
        return row
    }
}
