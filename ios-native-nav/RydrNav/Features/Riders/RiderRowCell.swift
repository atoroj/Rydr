import UIKit

/// Fila de la lista de Riders — espejo de la fila `is.riders` del
/// prototipo: cada fila es su propia tarjeta (no un simple renglón de
/// tabla), con avatar, nombre + candado si es privada, moto actual y un
/// botón de acción en píldora a la derecha.
final class RiderRowCell: UITableViewCell {
    var onPrimaryTapped: (() -> Void)?
    var onRejectTapped: (() -> Void)?

    private let card = UIView()
    private let avatarView = RemoteImageView()
    private let nameLabel = UILabel()
    private let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let motorbikeLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4.5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4.5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])

        avatarView.layer.cornerRadius = 22
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 44).isActive = true

        nameLabel.font = AppFont.body(15, .semibold)
        nameLabel.textColor = AppTheme.text

        lockIcon.tintColor = AppTheme.textSecondary(0.5)
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        lockIcon.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, lockIcon])
        nameRow.axis = .horizontal
        nameRow.spacing = 6
        nameRow.alignment = .center

        motorbikeLabel.styleAsLabel(size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [nameRow, motorbikeLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        primaryButton.titleLabel?.font = AppFont.body(12.5, .bold)
        primaryButton.titleLabel?.adjustsFontSizeToFitWidth = true
        primaryButton.titleLabel?.minimumScaleFactor = 0.8
        primaryButton.titleLabel?.lineBreakMode = .byClipping
        primaryButton.layer.cornerRadius = 11
        primaryButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        // Ancho fijo: el texto cambia según el estado ("Seguir", "Pendiente",
        // "Dejar de seguir"...) y sin esto cada fila quedaba con el botón a
        // un ancho distinto según cuánto ocupara su propio texto.
        primaryButton.widthAnchor.constraint(equalToConstant: 128).isActive = true
        primaryButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        primaryButton.addTarget(self, action: #selector(onTapPrimary), for: .touchUpInside)

        rejectButton.setTitle("Rechazar", for: .normal)
        rejectButton.titleLabel?.font = AppFont.body(13, .semibold)
        rejectButton.setTitleColor(.systemRed, for: .normal)
        rejectButton.addTarget(self, action: #selector(onTapReject), for: .touchUpInside)
        rejectButton.isHidden = true

        let buttonStack = UIStackView(arrangedSubviews: [rejectButton, primaryButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8

        let row = UIStackView(arrangedSubviews: [avatarView, textStack, buttonStack])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 11
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 11),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -11),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])
    }

    /// [primaryTitle] pasa `nil` para ocultar el botón principal (p. ej.
    /// tu propia fila). [showReject] añade el botón "Rechazar" (solicitudes).
    func configure(rider: RiderSummary, primaryTitle: String?, showReject: Bool = false) {
        nameLabel.text = rider.username
        lockIcon.isHidden = !rider.isPrivate
        motorbikeLabel.styleAsLabel(
            rider.currentMotorbike?.displayName ?? (rider.isPrivate ? "Cuenta privada" : "Sin moto en el garaje"),
            size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        avatarView.load(urlString: rider.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))

        primaryButton.isHidden = primaryTitle == nil
        primaryButton.setTitle(primaryTitle, for: .normal)
        if rider.followStatus == "following" || rider.followStatus == "pending" {
            primaryButton.setTitleColor(AppTheme.text, for: .normal)
            primaryButton.backgroundColor = AppTheme.bg3
            primaryButton.layer.borderWidth = 0
        } else {
            primaryButton.setTitleColor(AppTheme.bg0, for: .normal)
            primaryButton.backgroundColor = AppTheme.primary
            primaryButton.layer.borderWidth = 0
        }
        rejectButton.isHidden = !showReject
    }

    @objc private func onTapPrimary() { onPrimaryTapped?() }
    @objc private func onTapReject() { onRejectTapped?() }
}
