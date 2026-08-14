import PhotosUI
import UIKit

/// Espejo de lib/features/motorbikes/presentation/motorbikes_screen.dart —
/// galería de tarjetas ("Cada tarjeta de moto debe tener una fotografía,
/// marca, modelo y año", spec sección 3). Ya no es una pestaña del shell
/// (su sitio lo ocupa "Quedadas") — se abre desde el perfil propio
/// ("Ver mi garaje"), de ahí [showsTopBar].
final class MotorbikesViewController: UIViewController {
    private let showsTopBar: Bool
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    private let repository = MotorbikeRepository()
    private var motorbikes: [MotorbikeModel] = []
    private let cellId = "MotorbikeCard"

    init(showsTopBar: Bool = true) {
        self.showsTopBar = showsTopBar
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mis Motos"
        view.backgroundColor = .systemBackground
        if showsTopBar { installTopBar() }
        // installTopBar() ya puso el engranaje de ajustes a la derecha (si
        // se muestra); añadimos el "+" de esta pantalla como icono aparte.
        let addItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(onAddTapped))
        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem, addItem].compactMap { $0 }

        setupCollectionView()
        setupEmptyLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .estimated(220))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(MotorbikeCardCell.self, forCellWithReuseIdentifier: cellId)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.text = "Aún no tienes motos registradas"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func reload() {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        Task {
            do {
                motorbikes = try await repository.getMotorbikes(userId: userId)
                collectionView.reloadData()
                emptyLabel.isHidden = !motorbikes.isEmpty
            } catch {
                // Silencioso: si falla, se queda la lista anterior.
            }
        }
    }

    private func setCurrent(_ motorbike: MotorbikeModel) {
        Task {
            _ = try? await repository.setCurrent(motorbikeId: motorbike.id)
            reload()
        }
    }

    @objc private func onAddTapped() {
        presentForm(editing: nil)
    }

    private func presentForm(editing motorbike: MotorbikeModel?) {
        let formVC = AddMotorbikeViewController(editing: motorbike) { [weak self] in self?.reload() }
        present(UINavigationController(rootViewController: formVC), animated: true)
    }
}

extension MotorbikesViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        motorbikes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! MotorbikeCardCell
        let motorbike = motorbikes[indexPath.item]
        cell.configure(with: motorbike)
        cell.onSetCurrentTapped = { [weak self] in self?.setCurrent(motorbike) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        presentForm(editing: motorbikes[indexPath.item])
    }
}

/// Formulario modal para dar de alta o editar una moto — espejo de
/// `_AddMotorbikeSheet`. `editing != nil` cambia a modo edición: precarga
/// los campos, guarda con PATCH en vez de POST y añade "Eliminar moto".
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
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Guardar", style: .done, target: self, action: #selector(onSave))
        setupUI()
        populateIfEditing()
    }

    private func setupUI() {
        photoButton.setTitle("Añadir foto", for: .normal)
        photoButton.setImage(UIImage(systemName: "camera"), for: .normal)
        photoButton.backgroundColor = .secondarySystemBackground
        photoButton.layer.cornerRadius = 12
        photoButton.heightAnchor.constraint(equalToConstant: 120).isActive = true
        photoButton.addTarget(self, action: #selector(onPickPhoto), for: .touchUpInside)

        configureTypeMenu()

        brandField.placeholder = "Marca"
        brandField.borderStyle = .roundedRect

        modelField.placeholder = "Modelo"
        modelField.borderStyle = .roundedRect

        yearField.placeholder = "Año"
        yearField.borderStyle = .roundedRect
        yearField.keyboardType = .numberPad

        ccField.placeholder = "Cilindrada (cc)"
        ccField.borderStyle = .roundedRect
        ccField.keyboardType = .numberPad

        aliasField.placeholder = "Alias (opcional, p. ej. La Negra)"
        aliasField.borderStyle = .roundedRect

        deleteButton.setTitle("Eliminar moto", for: .normal)
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
        typeButton.setTitle("Tipo: \(motorbike.type)", for: .normal)
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
        typeButton.contentHorizontalAlignment = .leading
        typeButton.setTitleColor(.label, for: .normal)
        typeButton.backgroundColor = .secondarySystemBackground
        typeButton.layer.cornerRadius = 8
        typeButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        typeButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let actions = Self.types.map { type in
            UIAction(title: type) { [weak self] _ in
                self?.selectedType = type
                self?.typeButton.setTitle("Tipo: \(type)", for: .normal)
            }
        }
        typeButton.menu = UIMenu(children: actions)
        typeButton.showsMenuAsPrimaryAction = true
        typeButton.setTitle("Tipo: \(selectedType)", for: .normal)
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
                    self.showError("No se pudo eliminar: \(error.localizedDescription)")
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
            showError("Rellena marca, modelo y cilindrada.")
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
                showError("No se pudo guardar: \(error.localizedDescription)")
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Vaya", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
