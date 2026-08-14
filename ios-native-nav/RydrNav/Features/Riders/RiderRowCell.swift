import UIKit

/// Fila de la lista de Riders: avatar, nombre, moto actual y una acción a
/// la derecha (Seguir/Pendiente/Siguiendo, o Aceptar+Rechazar para
/// solicitudes). Espejo del listado "Amigos" del spec (sección 3).
final class RiderRowCell: UITableViewCell {
    var onPrimaryTapped: (() -> Void)?
    var onRejectTapped: (() -> Void)?

    private let avatarView = RemoteImageView()
    private let nameLabel = UILabel()
    private let motorbikeLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        avatarView.layer.cornerRadius = 20
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        nameLabel.font = .boldSystemFont(ofSize: 15)
        motorbikeLabel.font = .systemFont(ofSize: 13)
        motorbikeLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [nameLabel, motorbikeLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        primaryButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        primaryButton.addTarget(self, action: #selector(onTapPrimary), for: .touchUpInside)

        rejectButton.setTitle("Rechazar", for: .normal)
        rejectButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        rejectButton.setTitleColor(.systemRed, for: .normal)
        rejectButton.addTarget(self, action: #selector(onTapReject), for: .touchUpInside)
        rejectButton.isHidden = true

        let buttonStack = UIStackView(arrangedSubviews: [rejectButton, primaryButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8

        let row = UIStackView(arrangedSubviews: [avatarView, textStack, buttonStack])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    /// [primaryTitle] pasa `nil` para ocultar el botón principal (p. ej.
    /// tu propia fila). [showReject] añade el botón "Rechazar" (solicitudes).
    func configure(rider: RiderSummary, primaryTitle: String?, showReject: Bool = false) {
        nameLabel.text = rider.username
        motorbikeLabel.text = rider.currentMotorbike?.displayName ?? (rider.isPrivate ? "Cuenta privada" : "")
        avatarView.load(urlString: rider.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))

        primaryButton.isHidden = primaryTitle == nil
        primaryButton.setTitle(primaryTitle, for: .normal)
        rejectButton.isHidden = !showReject
    }

    @objc private func onTapPrimary() { onPrimaryTapped?() }
    @objc private func onTapReject() { onRejectTapped?() }
}
