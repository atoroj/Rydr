import UIKit

/// Tarjeta de quedada: título, quién la organiza, cuándo y dónde, aforo y
/// una acción (Unirme/Apuntado/Completa/Organizador).
final class MeetupCardCell: UICollectionViewCell {
    var onActionTapped: (() -> Void)?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM · HH:mm"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    private let card = UIView()
    private let privacyBadge = UILabel()
    private let titleLabel = UILabel()
    private let organizerLabel = UILabel()
    private let dateLabel = UILabel()
    private let locationLabel = UILabel()
    private let participantsLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        privacyBadge.font = .systemFont(ofSize: 11, weight: .bold)
        privacyBadge.textColor = .white
        privacyBadge.layer.cornerRadius = 7
        privacyBadge.clipsToBounds = true
        privacyBadge.textAlignment = .center

        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.numberOfLines = 2

        organizerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        organizerLabel.textColor = .secondaryLabel

        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel

        locationLabel.font = .systemFont(ofSize: 13)
        locationLabel.textColor = .secondaryLabel
        locationLabel.numberOfLines = 1

        participantsLabel.font = .systemFont(ofSize: 13)
        participantsLabel.textColor = .secondaryLabel

        actionButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 10
        actionButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        actionButton.addTarget(self, action: #selector(onTapAction), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [organizerLabel, dateLabel, locationLabel, participantsLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 3

        let textStack = UIStackView(arrangedSubviews: [titleLabel, infoStack, actionButton])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.setCustomSpacing(4, after: titleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(privacyBadge)
        card.addSubview(textStack)
        privacyBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            privacyBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            privacyBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            privacyBadge.heightAnchor.constraint(equalToConstant: 18),
            privacyBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: privacyBadge.leadingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        // El título no debe meterse debajo de la insignia: le damos ancho
        // completo aparte reduciendo el trailing solo para la insignia.
        NSLayoutConstraint.activate([
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -80),
        ])
    }

    func configure(with meetup: Meetup) {
        titleLabel.text = meetup.title
        organizerLabel.text = "Organiza \(meetup.organizer.username)"
        dateLabel.text = Self.dateFormatter.string(from: meetup.scheduledAt)
        locationLabel.text = meetup.locationName ?? "Punto de encuentro sin nombre"

        if let max = meetup.maxParticipants {
            participantsLabel.text = "\(meetup.participantCount)/\(max) apuntados"
        } else {
            participantsLabel.text = "\(meetup.participantCount) apuntado" + (meetup.participantCount == 1 ? "" : "s")
        }

        privacyBadge.text = meetup.isPrivate ? "  Amigos  " : "  Pública  "
        privacyBadge.backgroundColor = meetup.isPrivate ? .systemPurple : AppTheme.primary

        if meetup.isOrganizer {
            actionButton.setTitle("Eres el organizador", for: .normal)
            actionButton.backgroundColor = .systemGray
            actionButton.isEnabled = false
        } else if meetup.isJoined {
            actionButton.setTitle("Apuntado · toca para salir", for: .normal)
            actionButton.backgroundColor = .systemGray
            actionButton.isEnabled = true
        } else if meetup.isFull {
            actionButton.setTitle("Completa", for: .normal)
            actionButton.backgroundColor = .systemGray
            actionButton.isEnabled = false
        } else {
            actionButton.setTitle("Unirme", for: .normal)
            actionButton.backgroundColor = AppTheme.primary
            actionButton.isEnabled = true
        }
    }

    @objc private func onTapAction() { onActionTapped?() }
}
