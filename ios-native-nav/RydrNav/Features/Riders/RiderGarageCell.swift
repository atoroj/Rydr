import UIKit

/// Sección "Garaje" del perfil — espejo de la fila `prof.bikes` del
/// prototipo: tarjetas de moto en scroll horizontal, con insignia "Actual"
/// sobre la que está marcada como tal. En el perfil propio añade al final
/// una tarjeta "+ Añadir"; en el de otro rider solo se conoce su moto
/// actual (la API de perfil social no expone el resto del garaje ajeno),
/// así que ahí se muestra esa única tarjeta sin acción de añadir.
final class RiderGarageCell: UICollectionViewCell {
    var onAddTapped: (() -> Void)?
    var onBikeTapped: ((MotorbikeModel) -> Void)?

    private static let bikeCardWidth: CGFloat = 168

    private let sectionLabel = UILabel()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        sectionLabel.styleAsLabel("Garaje", size: 10.5, color: AppTheme.textSecondary(0.42), tracking: 1.4)
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .horizontal
        stack.spacing = 10
        // .fill (no .top): así la tarjeta "+ Añadir" estira a la misma
        // altura que las de moto en vez de quedarse con su tamaño
        // intrínseco (mucho más bajo, solo el icono).
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        contentView.addSubview(sectionLabel)
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 9),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 145),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    /// [showsAddCard] solo en el perfil propio.
    func configure(bikes: [MotorbikeModel], showsAddCard: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for bike in bikes {
            stack.addArrangedSubview(bikeCard(bike))
        }
        if showsAddCard {
            stack.addArrangedSubview(addCard())
        }
    }

    private func bikeCard(_ bike: MotorbikeModel) -> UIView {
        let card = UIView()
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = (bike.isCurrent ? AppTheme.primary.withAlphaComponent(0.5) : AppTheme.cardBorder).cgColor
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: Self.bikeCardWidth).isActive = true

        let photo = RemoteImageView()
        photo.backgroundColor = AppTheme.bg0
        photo.translatesAutoresizingMaskIntoConstraints = false
        photo.load(urlString: bike.photoUrl, placeholder: UIImage(systemName: "bicycle"))

        let badge = UILabel()
        badge.styleAsLabel("Actual", size: 9.5, color: AppTheme.bg0, tracking: 1.2)
        badge.backgroundColor = AppTheme.primary
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.isHidden = !bike.isCurrent
        badge.translatesAutoresizingMaskIntoConstraints = false

        let modelLabel = UILabel()
        modelLabel.text = bike.displayName
        modelLabel.font = AppFont.body(14.5, .semibold)
        modelLabel.textColor = AppTheme.text
        modelLabel.numberOfLines = 1

        // En el perfil de otro rider solo se conoce el modelo, el alias y
        // el año (la API de perfil social no expone tipo/cilindrada de una
        // moto ajena) — se arma la línea de specs solo con lo que hay.
        var specParts: [String] = []
        if !bike.type.isEmpty { specParts.append(bike.type) }
        if bike.cc > 0 { specParts.append("\(bike.cc)cc") }
        if let year = bike.year { specParts.append("\(year)") }
        let specLabel = UILabel()
        specLabel.styleAsLabel(specParts.joined(separator: " · "), size: 11, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [modelLabel, specLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(photo)
        card.addSubview(badge)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            photo.topAnchor.constraint(equalTo: card.topAnchor),
            photo.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            photo.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            photo.heightAnchor.constraint(equalToConstant: 92),

            badge.topAnchor.constraint(equalTo: photo.topAnchor, constant: 8),
            badge.trailingAnchor.constraint(equalTo: photo.trailingAnchor, constant: -8),
            badge.heightAnchor.constraint(equalToConstant: 18),

            textStack.topAnchor.constraint(equalTo: photo.bottomAnchor, constant: 10),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -11),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10),
        ])

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in self?.onBikeTapped?(bike) }, for: .touchUpInside)
        card.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    /// A todo lo alto de una tarjeta de moto y a un cuarto de su ancho —
    /// con el `.fill` del stack ya sale a la misma altura, aquí solo hace
    /// falta fijar el ancho.
    private func addCard() -> UIView {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = AppTheme.textSecondary(0.45)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: Self.bikeCardWidth / 4).isActive = true
        button.addTarget(self, action: #selector(onTapAdd), for: .touchUpInside)
        return button
    }

    @objc private func onTapAdd() { onAddTapped?() }
}
