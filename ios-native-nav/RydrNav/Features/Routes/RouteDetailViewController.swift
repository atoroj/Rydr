import CoreLocation
import MapboxMaps
import UIKit

/// Detalle de ruta — espejo de la pantalla `is.detail` del prototipo:
/// mapa a toda pantalla con botón atrás flotante, título grande, grid de
/// cifras, fila del publicador y un botón de "Iniciar navegación" a todo
/// lo ancho. Sustituye a la versión anterior (mapa fijo arriba + lista de
/// tres botones apilados), que no se parecía al diseño.
final class RouteDetailViewController: UIViewController {
    private let route: RouteModel
    private var mapView: MapView!
    private let statusLabel = UILabel()
    private let publisherAvatar = RemoteImageView()
    private let publisherNameLabel = UILabel()
    private let publisherMetaLabel = UILabel()
    private let publisherRow = UIView()

    init(route: RouteModel) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupUI()
        Task { await loadPublisher() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Mapa a toda pantalla, sin barra de sistema — el propio botón
        // atrás flotante hace ese papel, como en el prototipo.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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

        let backButton = floatingIconButton(systemName: "chevron.left")
        backButton.addTarget(self, action: #selector(onBackTapped), for: .touchUpInside)

        let nameLabel = UILabel()
        nameLabel.text = route.name
        nameLabel.font = AppFont.body(25, .semibold)
        nameLabel.textColor = AppTheme.text
        nameLabel.numberOfLines = 0

        let descriptionLabel = UILabel()
        descriptionLabel.text = route.description
        descriptionLabel.font = AppFont.body(14.5)
        descriptionLabel.textColor = AppTheme.textSecondary(0.6)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isHidden = route.description == nil || route.description!.isEmpty

        let statsRow = UIStackView(arrangedSubviews: [
            statCard(value: "\(route.distanceKm)", label: "Km"),
            statCard(value: "\(route.durationMinutes)", label: "Minutos"),
            statCard(value: "\(route.timesRidden)", label: route.timesRidden == 1 ? "Vez recorrida" : "Veces recorrida"),
        ])
        statsRow.axis = .horizontal
        statsRow.spacing = 10
        statsRow.distribution = .fillEqually

        setupPublisherRow()

        let googleMapsLink = linkButton("Navegar en Google Maps", action: #selector(onGoogleMapsTapped))
        let exportLink = linkButton("Exportar archivo GPX", action: #selector(onExportTapped))
        let offlineLink = linkButton("Guardar sin conexión", action: #selector(onOfflineTapped))
        let linksRow = UIStackView(arrangedSubviews: [googleMapsLink, exportLink, offlineLink])
        linksRow.axis = .horizontal
        linksRow.distribution = .fillEqually

        let startButton = UIButton(type: .system)
        startButton.setTitle("Iniciar navegación", for: .normal)
        startButton.titleLabel?.font = AppFont.body(17, .bold)
        startButton.setTitleColor(AppTheme.bg0, for: .normal)
        startButton.backgroundColor = AppTheme.primary
        startButton.layer.cornerRadius = 16
        startButton.heightAnchor.constraint(equalToConstant: 58).isActive = true
        startButton.addTarget(self, action: #selector(onFollowTapped), for: .touchUpInside)

        statusLabel.font = AppFont.body(13)
        statusLabel.textColor = AppTheme.textSecondary(0.5)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let contentStack = UIStackView(arrangedSubviews: [
            nameLabel, descriptionLabel, statsRow, publisherRow, startButton, linksRow, statusLabel,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.setCustomSpacing(16, after: statsRow)
        contentStack.setCustomSpacing(6, after: startButton)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(mapView)
        scrollView.addSubview(backButton)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mapView.widthAnchor.constraint(equalTo: view.widthAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 330),

            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),

            contentStack.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
        ])

        drawRouteOnMap()
    }

    private func setupPublisherRow() {
        publisherAvatar.layer.cornerRadius = 15
        publisherAvatar.translatesAutoresizingMaskIntoConstraints = false
        publisherAvatar.widthAnchor.constraint(equalToConstant: 30).isActive = true
        publisherAvatar.heightAnchor.constraint(equalToConstant: 30).isActive = true

        publisherNameLabel.font = AppFont.body(13.5, .semibold)
        publisherNameLabel.textColor = AppTheme.text

        publisherMetaLabel.styleAsLabel(size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [publisherNameLabel, publisherMetaLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [publisherAvatar, textStack])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        publisherRow.backgroundColor = AppTheme.cardBackground
        publisherRow.layer.cornerRadius = 12
        publisherRow.layer.borderWidth = 1
        publisherRow.layer.borderColor = AppTheme.cardBorder.cgColor
        publisherRow.isHidden = true
        publisherRow.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: publisherRow.topAnchor, constant: 11),
            row.bottomAnchor.constraint(equalTo: publisherRow.bottomAnchor, constant: -11),
            row.leadingAnchor.constraint(equalTo: publisherRow.leadingAnchor, constant: 13),
            row.trailingAnchor.constraint(lessThanOrEqualTo: publisherRow.trailingAnchor, constant: -13),
        ])
    }

    private func loadPublisher() async {
        guard let profile = try? await RidersRepository().profile(userId: route.authorId) else { return }
        publisherNameLabel.text = "Publicada por \(profile.username)"
        var meta = profile.currentMotorbike?.displayName ?? ""
        if profile.followStatus == "self" { meta = meta.isEmpty ? "Tu ruta" : "\(meta) · tu ruta" }
        publisherMetaLabel.styleAsLabel(meta, size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)
        publisherAvatar.loadAvatar(urlString: profile.avatarUrl, displayName: profile.username)
        publisherRow.isHidden = false
    }

    private func drawRouteOnMap() {
        let coordinates = route.path
        guard coordinates.count >= 2 else { return }

        let manager = mapView.annotations.makePolylineAnnotationManager()
        var polyline = PolylineAnnotation(lineCoordinates: coordinates)
        polyline.lineColor = StyleColor(AppTheme.primary)
        polyline.lineWidth = 4
        manager.annotations = [polyline]

        // `camera(for:padding:bearing:pitch:)` está obsoleto — la versión
        // nueva pide una `CameraOptions` base (vacía = usa lo que ya
        // tenga el mapa, igual que antes al no fijar bearing/pitch).
        if let camera = try? mapView.mapboxMap.camera(
            for: coordinates, camera: CameraOptions(),
            coordinatesPadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            maxZoom: nil, offset: nil)
        {
            mapView.mapboxMap.setCamera(to: camera)
        }
    }

    private func statCard(value: String, label: String) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.cardBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor

        let valueLabel = UILabel()
        valueLabel.attributedText = NSAttributedString(string: value, attributes: [
            .font: AppFont.data(24), .foregroundColor: AppTheme.text,
        ])
        let captionLabel = UILabel()
        captionLabel.styleAsLabel(label, size: 10.5, color: AppTheme.textSecondary(0.45), tracking: 1.2)

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

    private func floatingIconButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = AppTheme.text
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    private func linkButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var attributedTitle = AttributedString(title.uppercased())
        attributedTitle.font = AppFont.label(11.5)
        attributedTitle.kern = 0.6
        button.configuration = {
            var config = UIButton.Configuration.plain()
            config.attributedTitle = attributedTitle
            return config
        }()
        button.setTitleColor(AppTheme.textSecondary(0.55), for: .normal)
        button.tintColor = AppTheme.textSecondary(0.55)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func onBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func onFollowTapped() {
        // Antes arrancaba la guía directamente; ahora primero se ve el
        // recorrido completo (tu posición → inicio → final) y solo se
        // arranca de verdad al pulsar "Iniciar" ahí — al estilo Google Maps.
        let preview = RoutePreviewViewController(route: route)
        present(preview, animated: true)
    }

    @objc private func onGoogleMapsTapped() {
        let coordinates = route.path
        guard let first = coordinates.first, let last = coordinates.last else { return }

        var urlString = "https://www.google.com/maps/dir/?api=1"
            + "&origin=\(first.latitude),\(first.longitude)"
            + "&destination=\(last.latitude),\(last.longitude)"
            + "&travelmode=driving"

        if coordinates.count > 2 {
            let step = max(1, coordinates.count / 8)
            let waypoints = stride(from: step, to: coordinates.count - 1, by: step)
                .prefix(8)
                .map { "\(coordinates[$0].latitude),\(coordinates[$0].longitude)" }
                .joined(separator: "|")
            if !waypoints.isEmpty {
                urlString += "&waypoints=\(waypoints)"
            }
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func onOfflineTapped() {
        Task {
            statusLabel.text = "Calculando tamaño…"
            let estimate = await OfflineMapManager.shared.estimate(for: route)
            statusLabel.text = nil

            let sizeText: String
            if let estimate {
                sizeText = ByteCountFormatter.string(fromByteCount: Int64(estimate.storageSize), countStyle: .file)
            } else {
                sizeText = "un tamaño que no se ha podido calcular"
            }

            let alert = UIAlertController(
                title: "Guardar para sin conexión",
                message: "Se descargará el mapa y las carreteras de la zona de esta ruta — \(sizeText). "
                    + "Podrás navegarla sin datos móviles ni cobertura.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
            alert.addAction(UIAlertAction(title: "Descargar", style: .default) { [weak self] _ in
                self?.startOfflineDownload()
            })
            present(alert, animated: true)
        }
    }

    private func startOfflineDownload() {
        Task {
            do {
                try await OfflineMapManager.shared.download(for: route) { [weak self] progress in
                    Task { @MainActor in
                        self?.statusLabel.text = "Descargando… \(Int(progress * 100))%"
                    }
                }
                statusLabel.text = "Descarga completa — ya puedes navegar esta ruta sin conexión."
            } catch {
                statusLabel.text = "Error al descargar: \(error.localizedDescription)"
            }
        }
    }

    @objc private func onExportTapped() {
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        gpx += "<gpx version=\"1.1\" creator=\"RydrNav\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        gpx += "  <trk><name>\(route.name)</name><trkseg>\n"
        for point in route.path {
            gpx += "    <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"></trkpt>\n"
        }
        gpx += "  </trkseg></trk>\n</gpx>"

        let fileName = route.name.replacingOccurrences(of: " ", with: "_") + ".gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try gpx.write(to: url, atomically: true, encoding: .utf8)
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(activity, animated: true)
        } catch {
            statusLabel.text = "Error al exportar GPX: \(error.localizedDescription)"
        }
    }
}
