import CoreLocation
import PhotosUI
import UIKit

/// De dónde saca esta pantalla los datos de la ruta a publicar.
enum PublishSource {
    /// Justo después de terminar de grabar, en la misma sesión — el
    /// trazado/distancia/duración ya están completos en el propio móvil
    /// (`RegisterViewController.trackCoordinates` nunca depende de si la
    /// cola de `RideTrackSyncManager` ha terminado de llegar al backend
    /// todavía) y se mandan tal cual, sin pasar por `ride.track_points`
    /// del servidor — así publicar nunca sale incompleto por una
    /// sincronización aún en curso.
    case freshlyRecorded(coordinates: [CLLocationCoordinate2D], distanceKm: Double, durationMinutes: Int)
    /// Publicar un ride de una sesión anterior (desde "Mis rides") — aquí
    /// no hay nada en memoria de aquella grabación, así que sí hace falta
    /// que el backend derive el trazado de `ride.track_points` (ya
    /// sincronizados de sobra a estas alturas).
    case existingRide(rideId: Int)
}

/// Formulario para publicar un ride finalizado como ruta pública — sustituye
/// al `UIAlertController` con text fields que usaban antes
/// `HomeMapViewController`/`RidesHistoryViewController` (una alerta no
/// puede alojar un selector de foto). Espejo de `_PublishRideDialog`
/// (lib/features/register/presentation/register_screen.dart).
final class PublishRouteViewController: UIViewController {
    private let source: PublishSource
    private let pointCount: Int
    private let onPublished: () -> Void

    private let photoButton = UIButton(type: .system)
    private let nameField = UITextField()
    private let descriptionField = UITextField()
    private let statusLabel = UILabel()
    private var selectedImage: UIImage?

    init(source: PublishSource, pointCount: Int, onPublished: @escaping () -> Void) {
        self.source = source
        self.pointCount = pointCount
        self.onPublished = onPublished
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "¡Ruta completada!"
        view.backgroundColor = AppTheme.bg0
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Ahora no", style: .plain, target: self, action: #selector(onCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Publicar", style: .done, target: self, action: #selector(onPublish))
        setupUI()
    }

    private func setupUI() {
        let infoLabel = UILabel()
        infoLabel.text = "\(pointCount) puntos GPS grabados. ¿Quieres publicarla para otros moteros?"
        infoLabel.font = AppFont.body(14)
        infoLabel.numberOfLines = 0
        infoLabel.textColor = AppTheme.textSecondary(0.6)
        infoLabel.textAlignment = .center

        photoButton.setTitle("Foto de portada (opcional)", for: .normal)
        photoButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
        photoButton.tintColor = AppTheme.textSecondary(0.6)
        photoButton.setImage(UIImage(systemName: "photo.badge.plus"), for: .normal)
        photoButton.backgroundColor = AppTheme.cardBackground
        photoButton.layer.cornerRadius = 12
        photoButton.layer.borderWidth = 1
        photoButton.layer.borderColor = AppTheme.cardBorder.cgColor
        photoButton.contentVerticalAlignment = .center
        photoButton.heightAnchor.constraint(equalToConstant: 120).isActive = true
        photoButton.addTarget(self, action: #selector(onPickPhoto), for: .touchUpInside)

        nameField.placeholder = "Nombre de la ruta *"
        nameField.borderStyle = .roundedRect
        nameField.backgroundColor = AppTheme.bg2
        nameField.textColor = AppTheme.text

        descriptionField.placeholder = "Descripción (opcional)"
        descriptionField.borderStyle = .roundedRect
        descriptionField.backgroundColor = AppTheme.bg2
        descriptionField.textColor = AppTheme.text

        statusLabel.font = AppFont.body(13)
        statusLabel.textColor = AppTheme.textSecondary(0.5)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            infoLabel, photoButton, nameField, descriptionField, statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
    }

    @objc private func onPickPhoto() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func onCancel() {
        dismiss(animated: true)
    }

    @objc private func onPublish() {
        guard let name = nameField.text, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            statusLabel.text = "El nombre es obligatorio"
            return
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        statusLabel.text = selectedImage == nil ? "Publicando…" : "Subiendo foto y publicando…"

        Task {
            do {
                var coverImageUrl: String?
                if let selectedImage {
                    coverImageUrl = try await UploadsRepository().uploadImage(selectedImage)
                }
                let description = descriptionField.text?.trimmingCharacters(in: .whitespaces)
                let cleanDescription = description?.isEmpty == true ? nil : description

                switch source {
                case .freshlyRecorded(let coordinates, let distanceKm, let durationMinutes):
                    guard let authorId = AuthManager.shared.currentUser?.id else {
                        throw APIError(message: "Sesión no válida — vuelve a iniciar sesión.")
                    }
                    let geojson: [String: Any] = [
                        "type": "LineString",
                        "coordinates": coordinates.map { [$0.longitude, $0.latitude] },
                    ]
                    _ = try await RouteRepository().createRoute(
                        name: name, description: cleanDescription, authorId: authorId, geojson: geojson,
                        distanceKm: distanceKm, durationMinutes: durationMinutes, coverImageUrl: coverImageUrl)
                case .existingRide(let rideId):
                    _ = try await RouteRepository().createRoute(
                        fromRide: rideId, name: name, description: cleanDescription, coverImageUrl: coverImageUrl)
                }
                onPublished()
                dismiss(animated: true)
            } catch {
                navigationItem.rightBarButtonItem?.isEnabled = true
                statusLabel.text = "Error al publicar: \(error.localizedDescription)"
            }
        }
    }
}

extension PublishRouteViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.photoButton.setImage(nil, for: .normal)
                self?.photoButton.setTitle(nil, for: .normal)
                self?.photoButton.setBackgroundImage(image, for: .normal)
                self?.photoButton.imageView?.contentMode = .scaleAspectFill
                self?.photoButton.clipsToBounds = true
                self?.photoButton.layer.cornerRadius = 12
            }
        }
    }
}
