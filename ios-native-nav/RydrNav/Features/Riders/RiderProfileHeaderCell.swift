import UIKit

/// Cabecera del perfil social: foto grande, nombre, "Moto actual" (con
/// imagen) y el botón de seguir/pendiente/siguiendo — espejo de "Perfil
/// Social" (spec sección 3). Para cuentas privadas que no sigues, solo
/// muestra esto y un aviso, sin el feed de rutas.
final class RiderProfileHeaderCell: UICollectionViewCell {
    var onActionTapped: (() -> Void)?
    var onViewAllRoutesTapped: (() -> Void)?
    var onViewGarageTapped: (() -> Void)?

    private let avatarView = RemoteImageView()
    private let nameLabel = UILabel()
    private let viewAllRoutesButton = UIButton(type: .system)
    private let viewGarageButton = UIButton(type: .system)

    private let motorbikeCard = UIView()
    private let motorbikeImage = RemoteImageView()
    private let motorbikeLabel = UILabel()

    private let actionButton = UIButton(type: .system)
    private let privateNoticeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        avatarView.layer.cornerRadius = 48
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        nameLabel.font = .boldSystemFont(ofSize: 22)
        nameLabel.textAlignment = .center

        motorbikeImage.layer.cornerRadius = 12
        motorbikeImage.translatesAutoresizingMaskIntoConstraints = false
        motorbikeImage.widthAnchor.constraint(equalToConstant: 56).isActive = true
        motorbikeImage.heightAnchor.constraint(equalToConstant: 56).isActive = true

        motorbikeLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let motorbikeCaption = UILabel()
        motorbikeCaption.text = "Moto actual"
        motorbikeCaption.font = .systemFont(ofSize: 11)
        motorbikeCaption.textColor = .secondaryLabel

        let motorbikeTextStack = UIStackView(arrangedSubviews: [motorbikeCaption, motorbikeLabel])
        motorbikeTextStack.axis = .vertical
        motorbikeTextStack.spacing = 2

        let motorbikeRow = UIStackView(arrangedSubviews: [motorbikeImage, motorbikeTextStack])
        motorbikeRow.axis = .horizontal
        motorbikeRow.spacing = 12
        motorbikeRow.alignment = .center
        motorbikeRow.translatesAutoresizingMaskIntoConstraints = false

        motorbikeCard.backgroundColor = .secondarySystemBackground
        motorbikeCard.layer.cornerRadius = 14
        motorbikeCard.translatesAutoresizingMaskIntoConstraints = false
        motorbikeCard.addSubview(motorbikeRow)
        NSLayoutConstraint.activate([
            motorbikeRow.topAnchor.constraint(equalTo: motorbikeCard.topAnchor, constant: 10),
            motorbikeRow.bottomAnchor.constraint(equalTo: motorbikeCard.bottomAnchor, constant: -10),
            motorbikeRow.leadingAnchor.constraint(equalTo: motorbikeCard.leadingAnchor, constant: 12),
            motorbikeRow.trailingAnchor.constraint(equalTo: motorbikeCard.trailingAnchor, constant: -12),
        ])

        actionButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        actionButton.backgroundColor = AppTheme.primary
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 10
        actionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        actionButton.addTarget(self, action: #selector(onTapAction), for: .touchUpInside)

        privateNoticeLabel.text = "Cuenta privada. Solicita seguir para ver sus rutas."
        privateNoticeLabel.font = .systemFont(ofSize: 13)
        privateNoticeLabel.textColor = .secondaryLabel
        privateNoticeLabel.textAlignment = .center
        privateNoticeLabel.numberOfLines = 0

        // Solo en el perfil propio: "Mis Rutas" ya no es una pestaña, vive
        // aquí — ver sección de abajo son solo las últimas, este botón
        // lleva al listado completo.
        viewAllRoutesButton.setTitle("Ver todas mis rutas →", for: .normal)
        viewAllRoutesButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        viewAllRoutesButton.addTarget(self, action: #selector(onTapViewAllRoutes), for: .touchUpInside)
        viewAllRoutesButton.isHidden = true

        viewGarageButton.setTitle("Ver mi garaje →", for: .normal)
        viewGarageButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        viewGarageButton.addTarget(self, action: #selector(onTapViewGarage), for: .touchUpInside)
        viewGarageButton.isHidden = true

        let stack = UIStackView(arrangedSubviews: [
            avatarView, nameLabel, motorbikeCard, actionButton,
            viewGarageButton, viewAllRoutesButton, privateNoticeLabel,
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(20, after: nameLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            motorbikeCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func configure(with profile: RiderProfile) {
        nameLabel.text = profile.username
        avatarView.load(urlString: profile.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))

        if let motorbike = profile.currentMotorbike {
            motorbikeCard.isHidden = false
            motorbikeLabel.text = motorbike.displayName + (motorbike.year.map { " · \($0)" } ?? "")
            motorbikeImage.load(urlString: motorbike.photoUrl, placeholder: UIImage(systemName: "bicycle"))
        } else {
            motorbikeCard.isHidden = true
        }

        viewAllRoutesButton.isHidden = profile.followStatus != "self"
        viewGarageButton.isHidden = profile.followStatus != "self"

        switch profile.followStatus {
        case "self":
            actionButton.isHidden = true
        case "following":
            actionButton.isHidden = false
            actionButton.setTitle("Siguiendo · toca para dejar de seguir", for: .normal)
            actionButton.backgroundColor = .systemGray
        case "pending":
            actionButton.isHidden = false
            actionButton.setTitle("Solicitud pendiente", for: .normal)
            actionButton.backgroundColor = .systemGray
        default:
            actionButton.isHidden = false
            actionButton.setTitle(profile.isPrivate ? "Solicitar seguir" : "Seguir", for: .normal)
            actionButton.backgroundColor = AppTheme.primary
        }

        privateNoticeLabel.isHidden = profile.isVisible
    }

    @objc private func onTapAction() { onActionTapped?() }
    @objc private func onTapViewAllRoutes() { onViewAllRoutesTapped?() }
    @objc private func onTapViewGarage() { onViewGarageTapped?() }
}
