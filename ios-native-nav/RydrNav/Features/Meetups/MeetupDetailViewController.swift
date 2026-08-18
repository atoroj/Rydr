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

    // Tarjeta que sustituye al mapa mientras la ubicación exacta está
    // oculta para quien mira (`Meetup.coordinate == nil` — nunca pasa
    // para el organizador, que siempre recibe el punto real del backend).
    private let hiddenLocationCard = UIView()
    private let hiddenLocationLabel = UILabel()
    // Fila aparte, solo para el organizador: recordatorio + acción de
    // revelar — vive junto al mapa (que él sí ve bien), no dentro de
    // `hiddenLocationCard`.
    private let revealLocationRow = UIStackView()
    private let revealLocationLabel = UILabel()
    private let revealLocationButton = UIButton(type: .system)

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
        updateLocationDisplay()
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

        let hiddenCard = buildHiddenLocationCard()
        let revealRow = buildRevealLocationRow()

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
        locationLabel.text = meetup.coordinate != nil
            ? (meetup.locationName ?? "Punto de encuentro marcado en el mapa")
            : "Zona: \(meetup.approximateArea ?? "por confirmar")"
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
            mapView, hiddenCard, revealRow, badgeRow, organizerLabel, dateLabel, locationLabel, descriptionLabel,
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

    /// No-op si `meetup.coordinate` es `nil` — ubicación oculta para quien
    /// mira; `updateLocationDisplay()` se encarga de mostrar
    /// `hiddenLocationCard` en su lugar y deja `mapView` oculto.
    private func drawPin() {
        guard let coordinate = meetup.coordinate else { return }
        let manager = mapView.annotations.makePointAnnotationManager()
        let symbol = UIImage(systemName: "mappin.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32))!
        let markerImage = symbol.withTintColor(AppTheme.primary, renderingMode: .alwaysOriginal)
        var annotation = PointAnnotation(coordinate: coordinate)
        annotation.image = .init(image: markerImage, name: "meetup-pin")
        manager.annotations = [annotation]
        mapView.mapboxMap.setCamera(to: CameraOptions(center: coordinate, zoom: 12))
    }

    // MARK: - Ubicación oculta

    private func buildHiddenLocationCard() -> UIView {
        hiddenLocationCard.backgroundColor = AppTheme.bg2
        hiddenLocationCard.layer.cornerRadius = 14
        hiddenLocationCard.layer.borderWidth = 1
        hiddenLocationCard.layer.borderColor = AppTheme.cardBorder.cgColor
        hiddenLocationCard.heightAnchor.constraint(equalToConstant: 190).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
        icon.tintColor = AppTheme.accentTeal
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true

        hiddenLocationLabel.font = AppFont.body(14)
        hiddenLocationLabel.textColor = AppTheme.textSecondary(0.7)
        hiddenLocationLabel.textAlignment = .center
        hiddenLocationLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, hiddenLocationLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        hiddenLocationCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: hiddenLocationCard.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: hiddenLocationCard.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: hiddenLocationCard.centerYAnchor),
        ])
        return hiddenLocationCard
    }

    /// Solo para el organizador — el resto nunca ve esta fila (ellos, si
    /// la ubicación está oculta, ven `hiddenLocationCard` en su lugar;
    /// el organizador siempre ve el mapa real, pero necesita un sitio
    /// desde el que revelarlo al resto).
    private func buildRevealLocationRow() -> UIView {
        revealLocationLabel.font = AppFont.body(13)
        revealLocationLabel.textColor = AppTheme.textSecondary(0.55)
        revealLocationLabel.numberOfLines = 0

        var revealConfig = UIButton.Configuration.filled()
        revealConfig.title = "Revelar ubicación"
        revealConfig.baseBackgroundColor = AppTheme.accentTeal
        revealConfig.baseForegroundColor = AppTheme.bg0
        revealConfig.cornerStyle = .medium
        revealConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        revealConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppFont.body(13.5, .bold)
            return outgoing
        }
        revealLocationButton.configuration = revealConfig
        revealLocationButton.setContentHuggingPriority(.required, for: .horizontal)
        revealLocationButton.addTarget(self, action: #selector(onRevealLocationTapped), for: .touchUpInside)

        // Antes esto devolvía un `UIStackView` local distinto de la
        // propiedad `revealLocationRow` (que se quedaba como una `UIView`
        // vacía sin añadir a ningún sitio) — `updateLocationDisplay()`
        // ocultaba esa propiedad fantasma, nunca la fila que de verdad se
        // veía en pantalla, así que el botón salía para cualquiera.
        revealLocationRow.addArrangedSubview(revealLocationLabel)
        revealLocationRow.addArrangedSubview(revealLocationButton)
        revealLocationRow.axis = .horizontal
        revealLocationRow.alignment = .center
        revealLocationRow.spacing = 10
        return revealLocationRow
    }

    /// Se llama tras `setupUI()` y cada vez que `meetup` se refresca (al
    /// unirse/salir, o al revelar) — decide mapa vs. tarjeta oculta, y si
    /// enseñar la fila de "Revelar ubicación" al organizador.
    private func updateLocationDisplay() {
        let locationKnown = meetup.coordinate != nil
        mapView.isHidden = !locationKnown
        hiddenLocationCard.isHidden = locationKnown
        if !locationKnown {
            let area = meetup.approximateArea ?? "zona por confirmar"
            hiddenLocationLabel.text = meetup.isJoined
                ? "Estás apuntado — el organizador revelará el punto exacto más adelante.\nZona: \(area)."
                : "Apúntate para poder ver el punto exacto en cuanto el organizador lo revele.\nZona: \(area)."
        }

        let showsRevealRow = meetup.isOrganizer && meetup.locationHidden
        revealLocationRow.isHidden = !showsRevealRow
        guard showsRevealRow else { return }
        if meetup.locationRevealed {
            revealLocationLabel.text = "Ubicación ya revelada a los apuntados."
            revealLocationButton.isHidden = true
        } else {
            revealLocationLabel.text = "Ubicación oculta para quien no esté apuntado."
            revealLocationButton.isHidden = false
        }
    }

    @objc private func onRevealLocationTapped() {
        revealLocationButton.isEnabled = false
        Task {
            do {
                try await repository.revealLocation(id: meetup.id)
                if let refreshed = try? await repository.get(id: meetup.id) {
                    meetup = refreshed
                    drawPin()
                    updateLocationDisplay()
                    onChanged()
                }
            } catch {
                statusLabel.text = "Error al revelar: \(error.localizedDescription)"
            }
            revealLocationButton.isEnabled = true
        }
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
            showAlert(title: "Ubicación en vivo", message: "Necesitas dar permiso de ubicación para compartirla con el resto de apuntados.")
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
                    // Apuntarse/salir puede cambiar si ves el punto
                    // exacto (ver `MeetupService._to_view`) — p. ej. si ya
                    // estaba revelada, apuntarte la destapa al momento.
                    drawPin()
                    updateLocationDisplay()
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
