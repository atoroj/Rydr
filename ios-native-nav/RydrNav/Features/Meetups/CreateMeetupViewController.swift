import CoreLocation
import MapboxMaps
import UIKit

/// Crear o editar una quedada — espejo de la pantalla `is.meetForm` del
/// prototipo: campo de título en píldora con borde ámbar, descripción,
/// mapa con el punto de encuentro (tocar para marcarlo) y una etiqueta
/// superpuesta con el nombre del lugar, fecha/hora/aforo en tres tarjetas,
/// el interruptor pública/privada como dos botones, y un botón grande de
/// "Crear"/"Guardar" al final en vez del botón de la nav bar.
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
    private let locationOverlayLabel = UILabel()

    private let titleField = UITextField()
    private let descriptionView = UITextView()
    private let locationNameField = UITextField()
    private let datePicker = UIDatePicker()
    private let maxParticipantsField = UITextField()
    private let publicButton = UIButton(type: .system)
    private let privateButton = UIButton(type: .system)
    private var isPrivate = false
    private let hideLocationToggle = UISwitch()
    private let approximateAreaField = UITextField()
    private let deleteButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    init(editing: Meetup?, onSaved: @escaping () -> Void) {
        self.existingMeetup = editing
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingMeetup == nil ? "Nueva quedada" : "Editar quedada"
        view.backgroundColor = AppTheme.bg0
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
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

        titleField.attributedPlaceholder = NSAttributedString(
            string: "Título (p. ej. Ruta nocturna por la sierra)",
            attributes: [.foregroundColor: AppTheme.textSecondary(0.4)])
        stylePillField(titleField, amberBorder: true)
        titleField.font = AppFont.body(15.5, .semibold)
        titleField.textColor = AppTheme.text

        descriptionView.font = AppFont.body(14.5)
        descriptionView.backgroundColor = AppTheme.bg2
        descriptionView.layer.borderColor = AppTheme.cardBorder.cgColor
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.cornerRadius = 12
        descriptionView.textContainerInset = UIEdgeInsets(top: 12, left: 9, bottom: 12, right: 9)
        descriptionView.heightAnchor.constraint(equalToConstant: 90).isActive = true
        descriptionView.text = "Descripción (punto de salida, nivel, qué llevar...)"
        descriptionView.textColor = AppTheme.textSecondary(0.4)
        descriptionView.delegate = self

        setupMapPreview()

        locationNameField.attributedPlaceholder = NSAttributedString(
            string: "Nombre del punto de encuentro (opcional)",
            attributes: [.foregroundColor: AppTheme.textSecondary(0.4)])
        stylePillField(locationNameField, amberBorder: false)
        locationNameField.font = AppFont.body(14.5)
        locationNameField.textColor = AppTheme.text
        locationNameField.addTarget(self, action: #selector(onLocationNameChanged), for: .editingChanged)

        datePicker.datePickerMode = .dateAndTime
        datePicker.minimumDate = Date()
        datePicker.preferredDatePickerStyle = .compact
        datePicker.date = Date().addingTimeInterval(3600 * 24) // mañana, por defecto
        datePicker.overrideUserInterfaceStyle = .dark

        maxParticipantsField.attributedPlaceholder = NSAttributedString(
            string: "Sin límite", attributes: [.foregroundColor: AppTheme.textSecondary(0.4)])
        maxParticipantsField.font = AppFont.data(18)
        maxParticipantsField.textColor = AppTheme.text
        maxParticipantsField.keyboardType = .numberPad
        maxParticipantsField.textAlignment = .left

        let dateCard = fieldCard(caption: "Cuándo", content: datePicker)
        let aforoCard = fieldCard(caption: "Aforo", content: maxParticipantsField)
        let cardsRow = UIStackView(arrangedSubviews: [dateCard, aforoCard])
        cardsRow.axis = .horizontal
        cardsRow.spacing = 10
        cardsRow.distribution = .fillEqually

        configureVisibilityButtons()
        let visibilityRow = UIStackView(arrangedSubviews: [publicButton, privateButton])
        visibilityRow.axis = .horizontal
        visibilityRow.spacing = 10
        visibilityRow.distribution = .fillEqually

        let hideLocationRow = buildHideLocationRow()

        approximateAreaField.attributedPlaceholder = NSAttributedString(
            string: "Zona aproximada (p. ej. \"Sierra de Guadarrama\")",
            attributes: [.foregroundColor: AppTheme.textSecondary(0.4)])
        stylePillField(approximateAreaField, amberBorder: false)
        approximateAreaField.font = AppFont.body(14.5)
        approximateAreaField.textColor = AppTheme.text
        approximateAreaField.isHidden = true

        deleteButton.setTitle("Eliminar quedada", for: .normal)
        deleteButton.titleLabel?.font = AppFont.body(15, .semibold)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addTarget(self, action: #selector(onDeleteTapped), for: .touchUpInside)
        deleteButton.isHidden = existingMeetup == nil

        saveButton.setTitle(existingMeetup == nil ? "Crear quedada" : "Guardar cambios", for: .normal)
        saveButton.titleLabel?.font = AppFont.body(18, .bold)
        saveButton.setTitleColor(AppTheme.bg0, for: .normal)
        saveButton.backgroundColor = AppTheme.primary
        saveButton.layer.cornerRadius = 18
        saveButton.heightAnchor.constraint(equalToConstant: 64).isActive = true
        saveButton.addTarget(self, action: #selector(onSave), for: .touchUpInside)

        statusLabel.font = AppFont.body(13)
        statusLabel.textColor = AppTheme.textSecondary(0.5)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            titleField, descriptionView, mapContainer, locationNameField,
            cardsRow, visibilityRow, hideLocationRow, approximateAreaField,
            saveButton, statusLabel, deleteButton,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(6, after: saveButton)
        stack.setCustomSpacing(20, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private var mapContainer: UIView!

    private func setupMapPreview() {
        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onMapTapped(_:))))
        pointManager = mapView.annotations.makePointAnnotationManager()

        let container = UIView()
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 170).isActive = true
        container.addSubview(mapView)

        locationOverlayLabel.styleAsLabel(
            "Toca el mapa para marcar el punto de encuentro", size: 12.5, medium: true,
            color: AppTheme.textSecondary(0.8), tracking: 0.6)
        locationOverlayLabel.numberOfLines = 1
        locationOverlayLabel.textAlignment = .center
        locationOverlayLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        locationOverlayLabel.layer.cornerRadius = 10
        locationOverlayLabel.clipsToBounds = true
        locationOverlayLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(locationOverlayLabel)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: container.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            locationOverlayLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            locationOverlayLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            locationOverlayLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            locationOverlayLabel.heightAnchor.constraint(equalToConstant: 34),
        ])
        mapContainer = container
    }

    private func stylePillField(_ field: UITextField, amberBorder: Bool) {
        field.borderStyle = .none
        field.backgroundColor = AppTheme.bg2
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = (amberBorder ? AppTheme.primary.withAlphaComponent(0.45) : AppTheme.cardBorder).cgColor
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 13, height: 1))
        field.leftView = padding
        field.leftViewMode = .always
        field.rightView = padding
        field.rightViewMode = .always
    }

    private func fieldCard(caption: String, content: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.bg2
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor

        let captionLabel = UILabel()
        captionLabel.styleAsLabel(caption, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)

        let stack = UIStackView(arrangedSubviews: [captionLabel, content])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
        ])
        return container
    }

    private func configureVisibilityButtons() {
        for (button, title) in [(publicButton, "Pública"), (privateButton, "Solo mis riders")] {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = AppFont.body(13.5, .bold)
            button.layer.cornerRadius = 14
            button.layer.borderWidth = 1
            button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }
        publicButton.addTarget(self, action: #selector(onPickPublic), for: .touchUpInside)
        privateButton.addTarget(self, action: #selector(onPickPrivate), for: .touchUpInside)
        updateVisibilityButtons()
    }

    private func updateVisibilityButtons() {
        publicButton.backgroundColor = isPrivate ? AppTheme.bg2 : AppTheme.primary.withAlphaComponent(0.16)
        publicButton.layer.borderColor = (isPrivate ? AppTheme.cardBorder : AppTheme.primary.withAlphaComponent(0.5)).cgColor
        publicButton.setTitleColor(isPrivate ? AppTheme.textSecondary(0.5) : AppTheme.primary, for: .normal)

        privateButton.backgroundColor = isPrivate ? AppTheme.accentTeal.withAlphaComponent(0.16) : AppTheme.bg2
        privateButton.layer.borderColor = (isPrivate ? AppTheme.accentTeal.withAlphaComponent(0.5) : AppTheme.cardBorder).cgColor
        privateButton.setTitleColor(isPrivate ? AppTheme.accentTeal : AppTheme.textSecondary(0.5), for: .normal)
    }

    @objc private func onPickPublic() { isPrivate = false; updateVisibilityButtons() }
    @objc private func onPickPrivate() { isPrivate = true; updateVisibilityButtons() }

    /// Distinto de "Solo mis riders" (`isPrivate`, arriba): eso controla
    /// quién ve que la quedada EXISTE; esto controla quién ve el PUNTO
    /// EXACTO — pensado para anunciarla a todo el mundo (p. ej. un
    /// youtuber a su audiencia) pero que solo aparezca quien de verdad se
    /// apunte. Mientras esté oculta, se enseña la "zona aproximada" en su
    /// lugar — ver `MeetupDetailViewController`.
    private func buildHideLocationRow() -> UIView {
        let label = UILabel()
        label.text = "Ubicación privada — solo apuntados, cuando yo la revele"
        label.font = AppFont.body(14.5, .semibold)
        label.textColor = AppTheme.text
        label.numberOfLines = 0
        // Sin esto, con el texto largo (a diferencia del resto de switches
        // de la app, más cortos) el label y el switch empatan en
        // prioridad de compresión — el layout puede comprimir el switch a
        // un ancho casi nulo: se sigue viendo pero el área táctil real
        // desaparece, así que no responde al toque. El label cede (que
        // envuelva a más líneas), el switch nunca se encoge.
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        hideLocationToggle.onTintColor = AppTheme.accentTeal
        hideLocationToggle.setContentHuggingPriority(.required, for: .horizontal)
        hideLocationToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        hideLocationToggle.addTarget(self, action: #selector(onHideLocationToggled), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, hideLocationToggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }

    @objc private func onHideLocationToggled() {
        approximateAreaField.isHidden = !hideLocationToggle.isOn
    }

    @objc private func onLocationNameChanged() {
        let text = locationNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        locationOverlayLabel.styleAsLabel(
            text.isEmpty ? "Toca el mapa para marcar el punto de encuentro" : "Punto de encuentro · \(text)",
            size: 12.5, medium: true, color: AppTheme.textSecondary(0.8), tracking: 0.6)
    }

    private func populateIfEditing() {
        guard let meetup = existingMeetup else { return }
        titleField.text = meetup.title
        if let description = meetup.description, !description.isEmpty {
            descriptionView.text = description
            descriptionView.textColor = AppTheme.text
        }
        locationNameField.text = meetup.locationName
        onLocationNameChanged()
        datePicker.date = meetup.scheduledAt
        maxParticipantsField.text = meetup.maxParticipants.map(String.init)
        isPrivate = meetup.isPrivate
        updateVisibilityButtons()
        hideLocationToggle.setOn(meetup.locationHidden, animated: false)
        approximateAreaField.isHidden = !meetup.locationHidden
        approximateAreaField.text = meetup.approximateArea
        // El organizador siempre recibe el punto exacto del backend (ver
        // `MeetupService._to_view`), esté oculta para el resto o no — así
        // que al editar siempre hay una coordenada real que precargar.
        guard let coordinate = meetup.coordinate else { return }
        selectedCoordinate = coordinate
        placeMarker(at: coordinate)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: coordinate, zoom: 12))
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
                    self.showAlert(message: "No se pudo eliminar: \(error.localizedDescription)")
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func onSave() {
        guard let title = titleField.text, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlert(message: "Ponle un título a la quedada.")
            return
        }
        guard let coordinate = selectedCoordinate else {
            showAlert(message: "Marca el punto de encuentro tocando el mapa.")
            return
        }

        let description = descriptionView.textColor == AppTheme.textSecondary(0.4) ? nil : descriptionView.text
        let locationName = locationNameField.text?.trimmingCharacters(in: .whitespaces)
        let maxParticipants = maxParticipantsField.text.flatMap { Int($0) }
        let locationHidden = hideLocationToggle.isOn
        let approximateArea = approximateAreaField.text?.trimmingCharacters(in: .whitespaces)
        saveButton.isEnabled = false

        Task {
            do {
                if let meetup = existingMeetup {
                    _ = try await repository.update(
                        id: meetup.id, title: title, description: description,
                        locationName: locationName?.isEmpty == true ? nil : locationName,
                        coordinate: coordinate, scheduledAt: datePicker.date,
                        maxParticipants: maxParticipants, isPrivate: isPrivate,
                        locationHidden: locationHidden, approximateArea: approximateArea)
                } else {
                    _ = try await repository.create(
                        title: title, description: description,
                        locationName: locationName?.isEmpty == true ? nil : locationName,
                        coordinate: coordinate, scheduledAt: datePicker.date,
                        maxParticipants: maxParticipants, isPrivate: isPrivate,
                        locationHidden: locationHidden, approximateArea: approximateArea)
                }
                onSaved()
                dismiss(animated: true)
            } catch {
                saveButton.isEnabled = true
                showAlert(message: "No se pudo guardar: \(error.localizedDescription)")
            }
        }
    }

}

extension CreateMeetupViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == AppTheme.textSecondary(0.4) {
            textView.text = nil
            textView.textColor = AppTheme.text
        }
    }
}
