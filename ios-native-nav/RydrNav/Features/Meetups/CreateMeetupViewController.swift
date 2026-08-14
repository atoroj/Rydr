import CoreLocation
import MapboxMaps
import UIKit

/// Crear o editar una quedada: título, descripción, punto de encuentro
/// (tocar el mapa para colocarlo), fecha/hora, aforo máximo (opcional) y
/// si es privada (solo tus Riders) o pública (se apunta quien quiera).
final class CreateMeetupViewController: UIViewController {
    // Nombre distinto de "editing": UIViewController ya tiene una property
    // heredada `editing: Bool` (para el botón "Edit" de las nav bars) y
    // Swift no deja declarar una propia del mismo nombre con otro tipo.
    private let existingMeetup: Meetup?
    private let onSaved: () -> Void
    private let repository = MeetupsRepository()
    private let locationManager = CLLocationManager()

    private var mapView: MapView!
    private var pointManager: PointAnnotationManager?
    private var selectedCoordinate: CLLocationCoordinate2D?

    private let titleField = UITextField()
    private let descriptionView = UITextView()
    private let locationNameField = UITextField()
    private let datePicker = UIDatePicker()
    private let maxParticipantsField = UITextField()
    private let privateSwitch = UISwitch()
    private let deleteButton = UIButton(type: .system)

    init(editing: Meetup?, onSaved: @escaping () -> Void) {
        self.existingMeetup = editing
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingMeetup == nil ? "Nueva quedada" : "Editar quedada"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Guardar", style: .done, target: self, action: #selector(onSave))
        setupUI()
        populateIfEditing()
        if existingMeetup == nil { centerOnCurrentLocation() }
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        mapView.layer.cornerRadius = 12
        mapView.clipsToBounds = true
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onMapTapped(_:))))
        pointManager = mapView.annotations.makePointAnnotationManager()

        let mapHint = UILabel()
        mapHint.text = "Toca el mapa para marcar el punto de encuentro"
        mapHint.font = .systemFont(ofSize: 12)
        mapHint.textColor = .secondaryLabel
        mapHint.textAlignment = .center

        titleField.placeholder = "Título (p. ej. Ruta nocturna por la sierra)"
        titleField.borderStyle = .roundedRect

        descriptionView.font = .systemFont(ofSize: 15)
        descriptionView.layer.borderColor = UIColor.separator.cgColor
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.cornerRadius = 8
        descriptionView.heightAnchor.constraint(equalToConstant: 90).isActive = true
        descriptionView.text = "Descripción (punto de salida, nivel, qué llevar...)"
        descriptionView.textColor = .placeholderText
        descriptionView.delegate = self

        locationNameField.placeholder = "Nombre del punto de encuentro (opcional)"
        locationNameField.borderStyle = .roundedRect

        datePicker.datePickerMode = .dateAndTime
        datePicker.minimumDate = Date()
        datePicker.preferredDatePickerStyle = .compact
        datePicker.date = Date().addingTimeInterval(3600 * 24) // mañana, por defecto

        let dateRow = UIStackView(arrangedSubviews: [label("Cuándo"), datePicker])
        dateRow.axis = .horizontal
        dateRow.distribution = .equalSpacing

        maxParticipantsField.placeholder = "Máximo de participantes (opcional, vacío = sin límite)"
        maxParticipantsField.borderStyle = .roundedRect
        maxParticipantsField.keyboardType = .numberPad

        let privateRow = UIStackView(arrangedSubviews: [
            label("Privada · solo mis Riders"), UIView(), privateSwitch,
        ])
        privateRow.axis = .horizontal
        privateRow.alignment = .center

        deleteButton.setTitle("Eliminar quedada", for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addTarget(self, action: #selector(onDeleteTapped), for: .touchUpInside)
        deleteButton.isHidden = existingMeetup == nil

        let stack = UIStackView(arrangedSubviews: [
            mapView, mapHint, titleField, descriptionView, locationNameField,
            dateRow, maxParticipantsField, privateRow, deleteButton,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(4, after: mapView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15)
        return l
    }

    private func populateIfEditing() {
        guard let meetup = existingMeetup else { return }
        titleField.text = meetup.title
        if let description = meetup.description, !description.isEmpty {
            descriptionView.text = description
            descriptionView.textColor = .label
        }
        locationNameField.text = meetup.locationName
        datePicker.date = meetup.scheduledAt
        maxParticipantsField.text = meetup.maxParticipants.map(String.init)
        privateSwitch.isOn = meetup.isPrivate
        selectedCoordinate = meetup.coordinate
        placeMarker(at: meetup.coordinate)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: meetup.coordinate, zoom: 12))
    }

    private func centerOnCurrentLocation() {
        locationManager.delegate = nil
        locationManager.requestWhenInUseAuthorization()
        if let coordinate = locationManager.location?.coordinate {
            mapView.mapboxMap.setCamera(to: CameraOptions(center: coordinate, zoom: 11))
        }
    }

    @objc private func onMapTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.mapboxMap.coordinate(for: point)
        selectedCoordinate = coordinate
        placeMarker(at: coordinate)
    }

    private func placeMarker(at coordinate: CLLocationCoordinate2D) {
        let symbol = UIImage(systemName: "mappin.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32))!
        let markerImage = symbol.withTintColor(AppTheme.primary, renderingMode: .alwaysOriginal)
        var annotation = PointAnnotation(coordinate: coordinate)
        annotation.image = .init(image: markerImage, name: "meetup-pin")
        pointManager?.annotations = [annotation]
    }

    @objc private func onCancel() {
        dismiss(animated: true)
    }

    @objc private func onDeleteTapped() {
        guard let meetup = existingMeetup else { return }
        let alert = UIAlertController(
            title: "¿Eliminar \"\(meetup.title)\"?", message: "No se puede deshacer.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await self.repository.delete(id: meetup.id)
                    self.onSaved()
                    self.dismiss(animated: true)
                } catch {
                    self.showError("No se pudo eliminar: \(error.localizedDescription)")
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func onSave() {
        guard let title = titleField.text, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("Ponle un título a la quedada.")
            return
        }
        guard let coordinate = selectedCoordinate else {
            showError("Marca el punto de encuentro tocando el mapa.")
            return
        }

        let description = descriptionView.textColor == .placeholderText ? nil : descriptionView.text
        let locationName = locationNameField.text?.trimmingCharacters(in: .whitespaces)
        let maxParticipants = maxParticipantsField.text.flatMap { Int($0) }
        navigationItem.rightBarButtonItem?.isEnabled = false

        Task {
            do {
                if let meetup = existingMeetup {
                    _ = try await repository.update(
                        id: meetup.id, title: title, description: description,
                        locationName: locationName?.isEmpty == true ? nil : locationName,
                        coordinate: coordinate, scheduledAt: datePicker.date,
                        maxParticipants: maxParticipants, isPrivate: privateSwitch.isOn)
                } else {
                    _ = try await repository.create(
                        title: title, description: description,
                        locationName: locationName?.isEmpty == true ? nil : locationName,
                        coordinate: coordinate, scheduledAt: datePicker.date,
                        maxParticipants: maxParticipants, isPrivate: privateSwitch.isOn)
                }
                onSaved()
                dismiss(animated: true)
            } catch {
                navigationItem.rightBarButtonItem?.isEnabled = true
                showError("No se pudo guardar: \(error.localizedDescription)")
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Vaya", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CreateMeetupViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text = nil
            textView.textColor = .label
        }
    }
}
