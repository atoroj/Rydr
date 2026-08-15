import UIKit

/// Cabecera del perfil social — espejo de la cabecera `is.profile` del
/// prototipo: avatar grande con anillo ámbar, nombre + "handle", grid de
/// cifras y el botón de seguir/pendiente/siguiendo. El garaje y "últimas
/// rutas" viven en celdas propias más abajo (`RiderGarageCell`,
/// `RiderRouteRowCell`), no aquí.
final class RiderProfileHeaderCell: UICollectionViewCell {
    var onActionTapped: (() -> Void)?

    private let avatarView = RemoteImageView()
    private let nameLabel = UILabel()
    private let handleLabel = UILabel()
    private let statsStack = UIStackView()
    private let actionButton = UIButton(type: .system)
    private let privateNoticeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        avatarView.layer.cornerRadius = 37
        avatarView.layer.borderWidth = 2
        avatarView.layer.borderColor = AppTheme.primary.withAlphaComponent(0.5).cgColor
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 74).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 74).isActive = true

        nameLabel.font = AppFont.body(23, .semibold)
        nameLabel.textColor = AppTheme.text

        handleLabel.styleAsLabel(size: 12, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, handleLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 2

        let identityRow = UIStackView(arrangedSubviews: [avatarView, nameStack])
        identityRow.axis = .horizontal
        identityRow.spacing = 14
        identityRow.alignment = .center

        statsStack.axis = .horizontal
        statsStack.spacing = 10
        statsStack.distribution = .fillEqually

        actionButton.titleLabel?.font = AppFont.body(15, .bold)
        actionButton.layer.cornerRadius = 15
        actionButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        actionButton.addTarget(self, action: #selector(onTapAction), for: .touchUpInside)

        privateNoticeLabel.text = "Cuenta privada. Solicita seguir para ver sus rutas."
        privateNoticeLabel.font = AppFont.body(13)
        privateNoticeLabel.textColor = AppTheme.textSecondary(0.5)
        privateNoticeLabel.textAlignment = .center
        privateNoticeLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [identityRow, statsStack, actionButton, privateNoticeLabel])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(16, after: identityRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    func configure(with profile: RiderProfile) {
        nameLabel.text = profile.username
        handleLabel.styleAsLabel("@\(profile.username)", size: 12, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)
        avatarView.load(urlString: profile.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let totalKm = profile.recentRoutes.reduce(0) { $0 + $1.distanceKm }
        statsStack.addArrangedSubview(statCard(value: "\(profile.recentRoutes.count)", label: profile.recentRoutes.count == 1 ? "Ruta" : "Rutas"))
        statsStack.addArrangedSubview(statCard(value: String(format: "%.0f", totalKm), label: "Km"))

        switch profile.followStatus {
        case "self":
            actionButton.isHidden = true
        case "following":
            actionButton.isHidden = false
            actionButton.setTitle("Siguiendo · toca para dejar de seguir", for: .normal)
            actionButton.setTitleColor(AppTheme.text, for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
        case "pending":
            actionButton.isHidden = false
            actionButton.setTitle("Solicitud pendiente", for: .normal)
            actionButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
        default:
            actionButton.isHidden = false
            actionButton.setTitle(profile.isPrivate ? "Solicitar seguir" : "Seguir", for: .normal)
            actionButton.setTitleColor(AppTheme.bg0, for: .normal)
            actionButton.backgroundColor = AppTheme.primary
        }

        privateNoticeLabel.isHidden = profile.isVisible
    }

    private func statCard(value: String, label: String) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.cardBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor

        let valueLabel = UILabel()
        valueLabel.attributedText = NSAttributedString(string: value, attributes: [
            .font: AppFont.data(25), .foregroundColor: AppTheme.text,
        ])
        let captionLabel = UILabel()
        captionLabel.styleAsLabel(label, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -11),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
        ])
        return container
    }

    @objc private func onTapAction() { onActionTapped?() }
}
