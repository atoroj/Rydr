import UIKit

/// Tarjeta de quedada — espejo de la tarjeta `is.meets` del prototipo:
/// insignia de fecha (mes/día/hora) a la izquierda, título + etiqueta +
/// lugar a la derecha, tira de mapa con el punto de encuentro debajo, y
/// un pie con el aforo (barra de progreso) + botón de acción.
final class MeetupCardCell: UICollectionViewCell {
    var onActionTapped: (() -> Void)?

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private let card = UIView()
    private let dateBadge = UIView()
    private let monthLabel = UILabel()
    private let dayLabel = UILabel()
    private let timeLabel = UILabel()
    private let tagBackground = UIView()
    private let tagTextLabel = UILabel()
    private let titleLabel = UILabel()
    private let placeLabel = UILabel()
    private let mapImage = RemoteImageView()
    private let participantsLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint!
    private let actionButton = UIButton(type: .system)

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

        dateBadge.backgroundColor = AppTheme.bg0
        dateBadge.layer.cornerRadius = 12
        dateBadge.layer.borderWidth = 1
        dateBadge.layer.borderColor = AppTheme.cardBorder.cgColor
        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        dateBadge.widthAnchor.constraint(equalToConstant: 56).isActive = true

        monthLabel.styleAsLabel(size: 10, color: UIColor(hex: 0xFFC768), tracking: 1.2)
        monthLabel.textAlignment = .center
        dayLabel.font = AppFont.data(26)
        dayLabel.textColor = AppTheme.text
        dayLabel.textAlignment = .center
        timeLabel.styleAsLabel(size: 10.5, color: AppTheme.textSecondary(0.5), tracking: 0.8)
        timeLabel.textAlignment = .center

        let dateStack = UIStackView(arrangedSubviews: [monthLabel, dayLabel, timeLabel])
        dateStack.axis = .vertical
        dateStack.spacing = 1
        dateStack.alignment = .center
        dateStack.translatesAutoresizingMaskIntoConstraints = false
        dateBadge.addSubview(dateStack)
        NSLayoutConstraint.activate([
            dateStack.centerYAnchor.constraint(equalTo: dateBadge.centerYAnchor),
            dateStack.leadingAnchor.constraint(equalTo: dateBadge.leadingAnchor, constant: 4),
            dateStack.trailingAnchor.constraint(equalTo: dateBadge.trailingAnchor, constant: -4),
            dateStack.topAnchor.constraint(greaterThanOrEqualTo: dateBadge.topAnchor, constant: 8),
            dateStack.bottomAnchor.constraint(lessThanOrEqualTo: dateBadge.bottomAnchor, constant: -8),
        ])

        // El texto va en una etiqueta aparte dentro de `tagBackground`, con
        // el relleno puesto por constraints reales (no espacios sueltos en
        // el string): con el tracking del `styleAsLabel` unos espacios como
        // relleno quedan descentrados, porque el kerning también se aplica
        // a esos espacios y desplaza visualmente el texto dentro de la
        // píldora.
        tagBackground.layer.cornerRadius = 5
        tagBackground.clipsToBounds = true
        tagBackground.translatesAutoresizingMaskIntoConstraints = false
        tagTextLabel.translatesAutoresizingMaskIntoConstraints = false
        tagBackground.addSubview(tagTextLabel)
        NSLayoutConstraint.activate([
            tagTextLabel.topAnchor.constraint(equalTo: tagBackground.topAnchor, constant: 3),
            tagTextLabel.bottomAnchor.constraint(equalTo: tagBackground.bottomAnchor, constant: -3),
            tagTextLabel.leadingAnchor.constraint(equalTo: tagBackground.leadingAnchor, constant: 8),
            tagTextLabel.trailingAnchor.constraint(equalTo: tagBackground.trailingAnchor, constant: -8),
        ])

        titleLabel.font = AppFont.body(16.5, .semibold)
        titleLabel.textColor = AppTheme.text
        titleLabel.numberOfLines = 2

        placeLabel.styleAsLabel(size: 12, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        placeLabel.numberOfLines = 1

        let infoStack = UIStackView(arrangedSubviews: [tagBackground, titleLabel, placeLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 3
        infoStack.setCustomSpacing(2, after: tagBackground)
        infoStack.alignment = .leading
        // tagBackground es un pill de ancho ajustado al texto, no a todo lo
        // ancho del stack.
        tagBackground.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [dateBadge, infoStack])
        headerRow.axis = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .top
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        mapImage.backgroundColor = AppTheme.bg0
        mapImage.translatesAutoresizingMaskIntoConstraints = false

        participantsLabel.styleAsLabel(size: 12, medium: true, color: AppTheme.textSecondary(0.55), tracking: 0.6)

        progressTrack.backgroundColor = AppTheme.bg3
        progressTrack.layer.cornerRadius = 2.5
        progressTrack.clipsToBounds = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.heightAnchor.constraint(equalToConstant: 5).isActive = true

        progressFill.backgroundColor = AppTheme.primary
        progressFill.layer.cornerRadius = 2.5
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressWidthConstraint,
        ])

        let progressStack = UIStackView(arrangedSubviews: [participantsLabel, progressTrack])
        progressStack.axis = .vertical
        progressStack.spacing = 7

        // `UIButton.Configuration` en vez de `contentEdgeInsets` (obsoleto
        // desde iOS 15). El título/color se sigue fijando con los setters
        // clásicos más abajo — UIKit los sigue respetando con
        // configuration puesta, es solo `contentEdgeInsets` lo que
        // ignora — pero la fuente hay que fijarla vía
        // `titleTextAttributesTransformer`: como el botón cambia
        // `isEnabled` según el estado, un `titleLabel?.font` a pelo se
        // perdía cada vez que UIKit recalculaba la configuration.
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppFont.body(13.5, .bold)
            return outgoing
        }
        actionButton.configuration = config
        actionButton.layer.cornerRadius = 13
        actionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.addTarget(self, action: #selector(onTapAction), for: .touchUpInside)

        let footerRow = UIStackView(arrangedSubviews: [progressStack, actionButton])
        footerRow.axis = .horizontal
        footerRow.spacing = 12
        footerRow.alignment = .center
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        let footerContainer = UIView()
        footerContainer.translatesAutoresizingMaskIntoConstraints = false
        footerContainer.addSubview(footerRow)
        NSLayoutConstraint.activate([
            footerRow.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 12),
            footerRow.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -12),
            footerRow.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 13),
            footerRow.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -13),
        ])

        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(headerRow)
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 13),
            headerRow.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -13),
            headerRow.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 13),
            headerRow.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -13),
        ])

        let dividerTop = hairline()
        let dividerBottom = hairline()

        card.addSubview(headerContainer)
        card.addSubview(dividerTop)
        card.addSubview(mapImage)
        card.addSubview(dividerBottom)
        card.addSubview(footerContainer)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: card.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            dividerTop.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            dividerTop.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            dividerTop.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            mapImage.topAnchor.constraint(equalTo: dividerTop.bottomAnchor),
            mapImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            mapImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            mapImage.heightAnchor.constraint(equalToConstant: 96),

            dividerBottom.topAnchor.constraint(equalTo: mapImage.bottomAnchor),
            dividerBottom.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            dividerBottom.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            footerContainer.topAnchor.constraint(equalTo: dividerBottom.bottomAnchor),
            footerContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            footerContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            footerContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = AppTheme.cardBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    func configure(with meetup: Meetup) {
        monthLabel.styleAsLabel(Self.monthFormatter.string(from: meetup.scheduledAt), size: 10, color: UIColor(hex: 0xFFC768), tracking: 1.2)
        dayLabel.text = Self.dayFormatter.string(from: meetup.scheduledAt)
        timeLabel.styleAsLabel(Self.timeFormatter.string(from: meetup.scheduledAt), size: 10.5, color: AppTheme.textSecondary(0.5), tracking: 0.8)

        if meetup.isPrivate {
            tagTextLabel.styleAsLabel("solo riders", size: 10.5, color: AppTheme.accentTeal, tracking: 1)
            tagBackground.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.16)
        } else {
            tagTextLabel.styleAsLabel("pública", size: 10.5, color: AppTheme.primary, tracking: 1)
            tagBackground.backgroundColor = AppTheme.primary.withAlphaComponent(0.16)
        }

        titleLabel.text = meetup.title
        placeLabel.styleAsLabel(
            meetup.locationName ?? "Punto de encuentro sin nombre",
            size: 12, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        if let max = meetup.maxParticipants {
            participantsLabel.styleAsLabel(
                "\(meetup.participantCount)/\(max) apuntados", size: 12, medium: true,
                color: AppTheme.textSecondary(0.55), tracking: 0.6)
            let ratio = max > 0 ? CGFloat(meetup.participantCount) / CGFloat(max) : 0
            progressWidthConstraint.isActive = false
            progressWidthConstraint = progressFill.widthAnchor.constraint(
                equalTo: progressTrack.widthAnchor, multiplier: min(1, ratio))
            progressWidthConstraint.isActive = true
        } else {
            let label = meetup.participantCount == 1 ? "1 apuntado" : "\(meetup.participantCount) apuntados"
            participantsLabel.styleAsLabel(label, size: 12, medium: true, color: AppTheme.textSecondary(0.55), tracking: 0.6)
            progressWidthConstraint.isActive = false
            progressWidthConstraint = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 1)
            progressWidthConstraint.isActive = true
        }

        let snapshotURL = PinMapSnapshot.url(for: meetup.coordinate)
        mapImage.load(urlString: snapshotURL?.absoluteString, placeholder: UIImage(systemName: "map"))

        if meetup.isOrganizer {
            actionButton.setTitle("Organizas", for: .normal)
            actionButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
            actionButton.isEnabled = false
        } else if meetup.isJoined {
            actionButton.setTitle("Apuntado", for: .normal)
            actionButton.setTitleColor(AppTheme.text, for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
            actionButton.isEnabled = true
        } else if meetup.isFull {
            actionButton.setTitle("Completa", for: .normal)
            actionButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
            actionButton.isEnabled = false
        } else {
            actionButton.setTitle("Unirme", for: .normal)
            actionButton.setTitleColor(AppTheme.bg0, for: .normal)
            actionButton.backgroundColor = AppTheme.primary
            actionButton.isEnabled = true
        }
    }

    @objc private func onTapAction() { onActionTapped?() }
}
