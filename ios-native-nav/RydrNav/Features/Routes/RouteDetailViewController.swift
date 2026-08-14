import CoreLocation
import MapboxMaps
import UIKit

/// Espejo de `RouteDetailScreen` (lib/features/routes/presentation/routes_screen.dart).
final class RouteDetailViewController: UIViewController {
    private let route: RouteModel
    private var mapView: MapView!
    private let statusLabel = UILabel()

    init(route: RouteModel) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = route.name
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        // El mapa de arriba ya muestra el trazado; la foto que se sube al
        // publicar (si hay) se enseña aquí, no en la tarjeta del listado.
        let coverImage = RemoteImageView()
        coverImage.layer.cornerRadius = 12
        coverImage.heightAnchor.constraint(equalToConstant: 160).isActive = true
        coverImage.isHidden = route.coverImageUrl == nil
        if let coverImageUrl = route.coverImageUrl {
            coverImage.load(urlString: coverImageUrl, placeholder: UIImage(systemName: "photo"))
        }

        let descriptionLabel = UILabel()
        descriptionLabel.text = route.description
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isHidden = route.description == nil

        let statsStack = UIStackView(arrangedSubviews: [
            statView(icon: "ruler", value: "\(route.distanceKm) km", label: "Distancia"),
            statView(icon: "timer", value: "\(route.durationMinutes) min", label: "Duración"),
            statView(icon: "person.2", value: "\(route.timesRidden)", label: "La han hecho"),
        ])
        statsStack.distribution = .fillEqually

        let followButton = primaryButton("Seguir ruta en la app", action: #selector(onFollowTapped))
        let googleMapsButton = primaryButton("¡Navegar en Google Maps!", action: #selector(onGoogleMapsTapped))
        let exportButton = primaryButton("Exportar archivo GPX", action: #selector(onExportTapped))

        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            coverImage, descriptionLabel, statsStack, exportButton, googleMapsButton, followButton, statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 280),

            stack.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])

        drawRouteOnMap()
    }

    private func drawRouteOnMap() {
        let coordinates = route.path
        guard coordinates.count >= 2 else { return }

        let manager = mapView.annotations.makePolylineAnnotationManager()
        var polyline = PolylineAnnotation(lineCoordinates: coordinates)
        polyline.lineColor = StyleColor(AppTheme.primary)
        polyline.lineWidth = 4
        manager.annotations = [polyline]

        let camera = mapView.mapboxMap.camera(
            for: coordinates,
            padding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            bearing: nil, pitch: nil)
        mapView.mapboxMap.setCamera(to: camera)
    }

    private func statView(icon: String, value: String, label: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppTheme.primary
        iconView.contentMode = .scaleAspectFit
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .boldSystemFont(ofSize: 16)
        valueLabel.textAlignment = .center

        let captionLabel = UILabel()
        captionLabel.text = label
        captionLabel.font = .systemFont(ofSize: 11)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        return stack
    }

    private func primaryButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = AppTheme.primary
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
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
