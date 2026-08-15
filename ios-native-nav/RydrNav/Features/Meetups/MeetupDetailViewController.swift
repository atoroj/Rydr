import MapboxMaps
import UIKit

/// Detalle de una quedada: mapa con el punto de encuentro, descripción,
/// lista de apuntados y la acción según quién mira (unirse/salir, o editar
/// si eres el organizador).
final class MeetupDetailViewController: UIViewController {
    private var meetup: Meetup
    private let onChanged: () -> Void
    private let repository = MeetupsRepository()

    private var mapView: MapView!
    private var participants: [MeetupParticipant] = []
    private let participantsStack = UIStackView()
    private let actionButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d 'de' MMMM, HH:mm"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    init(meetup: Meetup, onChanged: @escaping () -> Void) {
        self.meetup = meetup
        self.onChanged = onChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = meetup.title
        view.backgroundColor = AppTheme.bg0
        if meetup.isOrganizer {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Editar", style: .plain, target: self, action: #selector(onEditTapped))
        }
        setupUI()
        Task { await loadParticipants() }
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 14
        mapView.layer.borderWidth = 1
        mapView.layer.borderColor = AppTheme.cardBorder.cgColor
        mapView.clipsToBounds = true
        mapView.heightAnchor.constraint(equalToConstant: 190).isActive = true
        drawPin()

        let badge = UILabel()
        badge.styleAsLabel(
            meetup.isPrivate ? " Privada · solo riders del organizador " : " Pública · abierta a todos ",
            size: 10.5, color: meetup.isPrivate ? AppTheme.accentTeal : AppTheme.primary, tracking: 0.8)
        badge.backgroundColor = (meetup.isPrivate ? AppTheme.accentTeal : AppTheme.primary).withAlphaComponent(0.14)
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let badgeRow = UIStackView(arrangedSubviews: [badge, UIView()])
        badgeRow.axis = .horizontal

        let organizerLabel = UILabel()
        organizerLabel.text = "Organiza \(meetup.organizer.username)"
        organizerLabel.font = AppFont.body(15, .semibold)
        organizerLabel.textColor = AppTheme.text

        let dateLabel = UILabel()
        dateLabel.text = Self.dateFormatter.string(from: meetup.scheduledAt)
        dateLabel.font = AppFont.body(15)
        dateLabel.textColor = AppTheme.textSecondary(0.6)

        let locationLabel = UILabel()
        locationLabel.text = meetup.locationName ?? "Punto de encuentro marcado en el mapa"
        locationLabel.font = AppFont.body(15)
        locationLabel.textColor = AppTheme.textSecondary(0.6)
        locationLabel.numberOfLines = 0

        let descriptionLabel = UILabel()
        descriptionLabel.text = meetup.description
        descriptionLabel.font = AppFont.body(15)
        descriptionLabel.textColor = AppTheme.text
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isHidden = meetup.description == nil || meetup.description!.isEmpty

        let participantsTitle = UILabel()
        participantsTitle.text = "Apuntados"
        participantsTitle.font = AppFont.body(16, .bold)
        participantsTitle.textColor = AppTheme.text

        participantsStack.axis = .vertical
        participantsStack.spacing = 8

        actionButton.titleLabel?.font = AppFont.body(17, .bold)
        actionButton.setTitleColor(AppTheme.text, for: .normal)
        actionButton.layer.cornerRadius = AppTheme.gloveButtonHeight / 2
        actionButton.heightAnchor.constraint(equalToConstant: AppTheme.gloveButtonHeight).isActive = true
        actionButton.addTarget(self, action: #selector(onActionTapped), for: .touchUpInside)
        configureActionButton()

        statusLabel.font = AppFont.body(13)
        statusLabel.textColor = AppTheme.textSecondary(0.5)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            mapView, badgeRow, organizerLabel, dateLabel, locationLabel, descriptionLabel,
            participantsTitle, participantsStack, actionButton, statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(16, after: descriptionLabel)
        stack.setCustomSpacing(16, after: participantsStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private func drawPin() {
        let manager = mapView.annotations.makePointAnnotationManager()
        let symbol = UIImage(systemName: "mappin.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32))!
        let markerImage = symbol.withTintColor(AppTheme.primary, renderingMode: .alwaysOriginal)
        var annotation = PointAnnotation(coordinate: meetup.coordinate)
        annotation.image = .init(image: markerImage, name: "meetup-pin")
        manager.annotations = [annotation]
        mapView.mapboxMap.setCamera(to: CameraOptions(center: meetup.coordinate, zoom: 12))
    }

    private func configureActionButton() {
        if meetup.isOrganizer {
            actionButton.isHidden = true
        } else if meetup.isJoined {
            actionButton.isHidden = false
            actionButton.setTitle("Salir de la quedada", for: .normal)
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.backgroundColor = .systemRed
        } else if meetup.isFull {
            actionButton.isHidden = false
            actionButton.setTitle("Completa", for: .normal)
            actionButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
            actionButton.backgroundColor = AppTheme.bg3
            actionButton.isEnabled = false
        } else {
            actionButton.isHidden = false
            actionButton.setTitle("Unirme", for: .normal)
            actionButton.setTitleColor(AppTheme.bg0, for: .normal)
            actionButton.backgroundColor = AppTheme.primary
            actionButton.isEnabled = true
        }
    }

    private func loadParticipants() async {
        participants = (try? await repository.participants(id: meetup.id)) ?? []
        participantsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for participant in participants {
            let row = UIStackView(arrangedSubviews: [
                avatarView(for: participant), participantLabel(for: participant),
            ])
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center
            participantsStack.addArrangedSubview(row)
        }
    }

    private func avatarView(for participant: MeetupParticipant) -> RemoteImageView {
        let view = RemoteImageView()
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 28).isActive = true
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        view.load(urlString: participant.avatarUrl, placeholder: UIImage(systemName: "person.circle.fill"))
        return view
    }

    private func participantLabel(for participant: MeetupParticipant) -> UILabel {
        let label = UILabel()
        label.text = participant.id == meetup.organizer.id ? "\(participant.username) · organiza" : participant.username
        label.font = AppFont.body(15)
        label.textColor = AppTheme.text
        return label
    }

    @objc private func onEditTapped() {
        let editVC = CreateMeetupViewController(editing: meetup) { [weak self] in self?.onChanged() }
        present(UINavigationController(rootViewController: editVC), animated: true)
    }

    @objc private func onActionTapped() {
        actionButton.isEnabled = false
        Task {
            do {
                if meetup.isJoined {
                    try await repository.leave(id: meetup.id)
                } else {
                    try await repository.join(id: meetup.id)
                }
                if let refreshed = try? await repository.get(id: meetup.id) {
                    meetup = refreshed
                    configureActionButton()
                    await loadParticipants()
                    onChanged()
                }
            } catch {
                statusLabel.text = "Error: \(error.localizedDescription)"
            }
            actionButton.isEnabled = true
        }
    }
}
