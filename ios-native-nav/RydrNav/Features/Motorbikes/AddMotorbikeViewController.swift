import PhotosUI
import UIKit

/// Formulario modal para dar de alta o editar una moto — espejo de
/// `_AddMotorbikeSheet`. `editing != nil` cambia a modo edición: precarga
/// los campos, guarda con PATCH en vez de POST y añade "Eliminar moto".
/// Se abre desde el "Garaje" del perfil propio (`RiderGarageCell`), que
/// sustituyó a la galería de tarjetas independiente que había antes — ya
/// no hace falta una pantalla de listado aparte, el propio scroll
/// horizontal del perfil hace ese papel (espejo del prototipo de diseño).
final class AddMotorbikeViewController: UIViewController {
    // Nombre distinto de "editing": UIViewController ya tiene una property
    // heredada `editing: Bool` (para el botón "Edit" de las nav bars) y
    // Swift no deja declarar una propia del mismo nombre con otro tipo.
    private let existingMotorbike: MotorbikeModel?
    private let onSaved: () -> Void
    private let repository = MotorbikeRepository()

    private let photoButton = UIButton(type: .system)
    private let typeButton = UIButton(type: .system)
    private let brandField = UITextField()
    private let modelField = UITextField()
    private let yearField = UITextField()
    private let ccField = UITextField()
    private let aliasField = UITextField()
    private let deleteButton = UIButton(type: .system)
    private var selectedType = "Naked"
    private var selectedImage: UIImage?

    private static let types = ["Naked", "Sport", "Custom", "ATV", "Touring", "Motocross", "Scooter"]

    init(editing: MotorbikeModel? = nil, onSaved: @escaping () -> Void) {
        self.existingMotorbike = editing
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingMotorbike == nil ? "Nueva moto" : "Editar moto"
        view.backgroundColor = AppTheme.bg0
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Guardar", style: .done, target: self, action: #selector(onSave))
        setupUI()
        populateIfEditing()
    }

    private func setupUI() {
        photoButton.setTitle("Añadir foto", for: .normal)
        photoButton.setTitleColor(AppTheme.textSecondary(0.6), for: .normal)
        photoButton.tintColor = AppTheme.textSecondary(0.6)
        photoButton.setImage(UIImage(systemName: "camera"), for: .normal)
        photoButton.backgroundColor = AppTheme.cardBackground
        photoButton.layer.cornerRadius = 12
        photoButton.layer.borderWidth = 1
        photoButton.layer.borderColor = AppTheme.cardBorder.cgColor
        photoButton.heightAnchor.constraint(equalToConstant: 120).isActive = true
        photoButton.addTarget(self, action: #selector(onPickPhoto), for: .touchUpInside)

        configureTypeMenu()

        brandField.placeholder = "Marca"
        brandField.borderStyle = .roundedRect
        brandField.backgroundColor = AppTheme.bg2
        brandField.textColor = AppTheme.text

        modelField.placeholder = "Modelo"
        modelField.borderStyle = .roundedRect
        modelField.backgroundColor = AppTheme.bg2
        modelField.textColor = AppTheme.text

        yearField.placeholder = "Año"
        yearField.borderStyle = .roundedRect
        yearField.backgroundColor = AppTheme.bg2
        yearField.textColor = AppTheme.text
        yearField.keyboardType = .numberPad

        ccField.placeholder = "Cilindrada (cc)"
        ccField.borderStyle = .roundedRect
        ccField.backgroundColor = AppTheme.bg2
        ccField.textColor = AppTheme.text
        ccField.keyboardType = .numberPad

        aliasField.placeholder = "Alias (opcional, p. ej. La Negra)"
        aliasField.borderStyle = .roundedRect
        aliasField.backgroundColor = AppTheme.bg2
        aliasField.textColor = AppTheme.text

        deleteButton.setTitle("Eliminar moto", for: .normal)
        deleteButton.titleLabel?.font = AppFont.body(15, .semibold)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addTarget(self, action: #selector(onDeleteTapped), for: .touchUpInside)
        deleteButton.isHidden = existingMotorbike == nil

        let stack = UIStackView(arrangedSubviews: [
            photoButton, typeButton, brandField, modelField, yearField, ccField, aliasField, deleteButton,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
    }

    private func populateIfEditing() {
        guard let motorbike = existingMotorbike else { return }
        selectedType = motorbike.type
        setTypeButtonTitle("Tipo: \(motorbike.type)")
        brandField.text = motorbike.brand
        modelField.text = motorbike.model
        yearField.text = motorbike.year.map(String.init)
        ccField.text = String(motorbike.cc)
        aliasField.text = motorbike.alias
        if let photoUrl = motorbike.photoUrl, let url = RemoteImageView.resolvedURL(photoUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.applyPhotoPreview(image) }
            }.resume()
        }
    }

    private func configureTypeMenu() {
        // `UIButton.Configuration` en vez de `contentEdgeInsets` (obsoleto
        // desde iOS 15 y, de hecho, ignorado si se usa configuration) —
        // `setTypeButtonTitle` de abajo mantiene el resto de propiedades
        // (color, alineación) al actualizar el texto.
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppTheme.text
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        typeButton.configuration = config
        typeButton.contentHorizontalAlignment = .leading
        typeButton.backgroundColor = AppTheme.bg2
        typeButton.layer.cornerRadius = 8
        typeButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let actions = Self.types.map { type in
            UIAction(title: type) { [weak self] _ in
                self?.selectedType = type
                self?.setTypeButtonTitle("Tipo: \(type)")
            }
        }
        typeButton.menu = UIMenu(children: actions)
        typeButton.showsMenuAsPrimaryAction = true
        setTypeButtonTitle("Tipo: \(selectedType)")
    }

    private func setTypeButtonTitle(_ title: String) {
        typeButton.configuration?.title = title
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

    @objc private func onDeleteTapped() {
        guard let motorbike = existingMotorbike else { return }
        let alert = UIAlertController(
            title: "¿Eliminar \(motorbike.displayName)?", message: "No se puede deshacer.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await self.repository.deleteMotorbike(id: motorbike.id)
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
        guard let brand = brandField.text, !brand.isEmpty,
              let model = modelField.text, !model.isEmpty,
              let ccText = ccField.text, let cc = Int(ccText)
        else {
            showAlert(message: "Rellena marca, modelo y cilindrada.")
            return
        }

        let alias = aliasField.text?.trimmingCharacters(in: .whitespaces)
        let year = yearField.text.flatMap { Int($0) }
        navigationItem.rightBarButtonItem?.isEnabled = false

        Task {
            do {
                var photoUrl: String?
                if let selectedImage {
                    photoUrl = try await UploadsRepository().uploadImage(selectedImage)
                }

                if let motorbike = existingMotorbike {
                    _ = try await repository.updateMotorbike(
                        id: motorbike.id, type: selectedType, brand: brand, model: model, cc: cc,
                        alias: alias?.isEmpty == true ? nil : alias, year: year, photoUrl: photoUrl)
                } else {
                    guard let userId = AuthManager.shared.currentUser?.id else { return }
                    _ = try await repository.createMotorbike(
                        userId: userId, type: selectedType, brand: brand, model: model, cc: cc,
                        alias: alias?.isEmpty == true ? nil : alias, year: year, photoUrl: photoUrl)
                }
                onSaved()
                dismiss(animated: true)
            } catch {
                navigationItem.rightBarButtonItem?.isEnabled = true
                showAlert(message: "No se pudo guardar: \(error.localizedDescription)")
            }
        }
    }


    private func applyPhotoPreview(_ image: UIImage) {
        photoButton.setTitle(nil, for: .normal)
        photoButton.setImage(nil, for: .normal)
        photoButton.setBackgroundImage(image, for: .normal)
        photoButton.imageView?.contentMode = .scaleAspectFill
        photoButton.clipsToBounds = true
    }
}

extension AddMotorbikeViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.applyPhotoPreview(image)
            }
        }
    }
}
