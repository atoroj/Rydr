import CoreLocation
import MapboxMaps
import UIKit

/// Detalle de una quedada: mapa con el punto de encuentro, descripción,
/// lista de apuntados y la acción según quién mira (unirse/salir, o editar
/// si eres el organizador). Si la quedada es hoy, también deja compartir tu
/// ubicación en vivo con el resto de apuntados (y ver la suya) — el ángulo
/// "REVER" frente a Calimoto, apoyado en la base social que ya tiene Rydr.
final class MeetupDetailViewController: UIViewController {
    private var meetup: Meetup
    private let onChanged: () -> Void
    private let repository = MeetupsRepository()

    private var mapView: MapView!
    private var participants: [MeetupParticipant] = []
    private let participantsStack = UIStackView()
    private let actionButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    // Ubicación en vivo — solo si la quedada es hoy. Compartir la propia y
    // ver la de los demás son cosas independientes: se puede ver el mapa en
    // vivo sin compartir la tuya.
    private let locationManager = CLLocationManager()
    private let shareLocationToggle = UISwitch()
    private var liveLocationsManager: PointAnnotationManager?
    private var shareLocationTimer: Timer?
    private var pollLiveLocationsTimer: Timer?
    private var isSharingLocation = false

    private var isMeetupToday: Bool { Calendar.current.isDateInToday(meetup.scheduledAt) }

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ver el mapa en vivo no depende de estar compartiendo tu propia
        // ubicación — el poll de los demás arranca solo con entrar, si la
        // quedada es hoy.
        if isMeetupToday { startPollingLiveLocations() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Al salir de la pantalla se para todo — tanto ver como compartir
        // son cosas de "mientras estás mirando esta quedada", no un estado
        // de fondo indefinido.
        pollLiveLocationsTimer?.invalidate()
        stopSharingLocation()
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

        let shareLocationRow = buildShareLocationRow()

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
            shareLocationRow, participantsTitle, participantsStack, actionButton, statusLabel,
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

    // MARK: - Ubicación en vivo

    /// Solo se enseña si la quedada es hoy — no tiene sentido "compartir
    /// ubicación en vivo" para algo que es dentro de dos semanas.
    private func buildShareLocationRow() -> UIView {
        let label = UILabel()
        label.text = "Compartir mi ubicación en vivo"
        label.font = AppFont.body(15, .semibold)
        label.textColor = AppTheme.text

        shareLocationToggle.onTintColor = AppTheme.primary
        shareLocationToggle.addTarget(self, action: #selector(onShareLocationToggled), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, shareLocationToggle])
        row.axis = .horizontal
        row.alignment = .center
        row.isHidden = !isMeetupToday
        return row
    }

    @objc private func onShareLocationToggled() {
        if shareLocationToggle.isOn {
            startSharingLocation()
        } else {
            stopSharingLocation()
        }
    }

    private func startSharingLocation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        guard locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
        else {
            shareLocationToggle.setOn(false, animated: true)
            showAlert(message: "Necesitas dar permiso de ubicación para compartirla con el resto de apuntados.")
            return
        }
        locationManager.delegate = self
        isSharingLocation = true
        // Un `requestLocation()` puntual cada 10s, no `startUpdatingLocation()`
        // continuo — esta pantalla solo comparte mientras está en primer
        // plano (ver viewWillDisappear), así que no hace falta ni el gasto
        // de batería ni la autorización "Siempre" que sí necesita grabar
        // una ruta de verdad en segundo plano.
        shareLocationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.locationManager.requestLocation()
        }
        locationManager.requestLocation()
    }

    private func stopSharingLocation() {
        isSharingLocation = false
        shareLocationTimer?.invalidate()
        shareLocationTimer = nil
        if shareLocationToggle.isOn { shareLocationToggle.setOn(false, animated: false) }
    }

    private func startPollingLiveLocations() {
        pollLiveLocationsTimer?.invalidate()
        pollLiveLocationsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { await self?.refreshLiveLocations() }
        }
        Task { await refreshLiveLocations() }
    }

    private func refreshLiveLocations() async {
        guard let locations = try? await repository.liveLocations(id: meetup.id) else { return }
        let manager = liveLocationsManager ?? mapView.annotations.makePointAnnotationManager()
        liveLocationsManager = manager
        manager.annotations = locations.map { location in
            var annotation = PointAnnotation(coordinate: location.coordinate)
            let markerImage = RemoteImageView.initialsAvatar(for: location.username, size: CGSize(width: 40, height: 40))
            annotation.image = .init(image: markerImage, name: "live-\(location.userId)")
            return annotation
        }
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
        view.loadAvatar(urlString: participant.avatarUrl, displayName: participant.username)
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

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Ubicación en vivo", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension MeetupDetailViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isSharingLocation, let coordinate = locations.last?.coordinate else { return }
        Task { try? await repository.updateLocation(id: meetup.id, coordinate: coordinate) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Un fallo puntual del GPS no merece una alerta — se reintenta solo
        // en el siguiente disparo del timer.
    }
}
