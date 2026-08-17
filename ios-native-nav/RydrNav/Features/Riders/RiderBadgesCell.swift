import UIKit

/// Sección "Insignias" del perfil — mismo patrón que `RiderGarageCell`
/// (etiqueta + scroll horizontal dentro de una única celda): un chip por
/// insignia, iluminado en ámbar si está conseguida, atenuado en gris si
/// no — de un vistazo se ve tanto lo logrado como lo que falta, sin
/// escondrer las que aún no se tienen.
final class RiderBadgesCell: UICollectionViewCell {
    private static let chipWidth: CGFloat = 92

    private let sectionLabel = UILabel()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        sectionLabel.styleAsLabel("Insignias", size: 10.5, color: AppTheme.textSecondary(0.42), tracking: 1.4)
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .horizontal
        stack.spacing = 10
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
            scrollView.heightAnchor.constraint(equalToConstant: 104),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    func configure(badges: [BadgeModel]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for badge in badges {
            stack.addArrangedSubview(chip(for: badge))
        }
    }

    private func chip(for badge: BadgeModel) -> UIView {
        let card = UIView()
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = (badge.achieved ? AppTheme.primary.withAlphaComponent(0.5) : AppTheme.cardBorder).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: Self.chipWidth).isActive = true

        let iconBackground = UIView()
        iconBackground.backgroundColor = (badge.achieved ? AppTheme.primary : AppTheme.bg3).withAlphaComponent(badge.achieved ? 0.16 : 1)
        iconBackground.layer.cornerRadius = 18
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBackground.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let icon = UIImageView(image: UIImage(systemName: badge.icon))
        icon.tintColor = badge.achieved ? AppTheme.primary : AppTheme.textSecondary(0.35)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
        ])

        let titleLabel = UILabel()
        titleLabel.text = badge.title
        titleLabel.font = AppFont.body(11, .semibold)
        titleLabel.textColor = badge.achieved ? AppTheme.text : AppTheme.textSecondary(0.4)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [iconBackground, titleLabel])
        textStack.axis = .vertical
        textStack.spacing = 7
        textStack.alignment = .center
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
        ])

        // Sin acción al tocar de momento — la descripción (`badge.description`)
        // se deja lista en el modelo para un futuro popover/detalle, pero
        // no es imprescindible para que la insignia sea útil de un vistazo.
        return card
    }
}
