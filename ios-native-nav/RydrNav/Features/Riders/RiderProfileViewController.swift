import UIKit

/// Perfil social de un rider — espejo de la pantalla `is.profile` del
/// prototipo: cabecera con atrás + etiqueta, avatar/nombre/cifras/acción,
/// "Garaje" en scroll horizontal y "Últimas rutas" en filas compactas.
/// `userId nil` = el perfil propio (se abre pulsando el avatar de la top
/// bar); cuentas privadas que no sigues solo muestran la cabecera + botón
/// de solicitud.
final class RiderProfileViewController: UIViewController {
    private enum Section: Int, CaseIterable { case header, badges, garage, routes }

    private let userId: Int?
    private let repository = RidersRepository()
    private let motorbikeRepository = MotorbikeRepository()
    private let badgesRepository = BadgesRepository()

    private var collectionView: UICollectionView!
    private var profile: RiderProfile?
    private var ownGarage: [MotorbikeModel] = []
    private var badges: [BadgeModel] = []
    private let headerCellId = "Header"
    private let badgesCellId = "Badges"
    private let garageCellId = "Garage"
    private let routeCellId = "RouteRow"

    private var resolvedUserId: Int? { userId ?? AuthManager.shared.currentUser?.id }
    private var isOwnProfile: Bool { userId == nil || userId == AuthManager.shared.currentUser?.id }

    init(userId: Int?) {
        self.userId = userId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.bg0
        setupHeader()
        setupCollectionView()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // Cabecera "atrás + etiqueta" — espejo del patrón que usa el
    // prototipo en todas las pantallas empujadas (detalle, ajustes...).
    private func setupHeader() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = AppTheme.text
        backButton.backgroundColor = AppTheme.cardBackground
        backButton.layer.cornerRadius = 11
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = AppTheme.cardBorder.cgColor
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.widthAnchor.constraint(equalToConstant: 38).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        backButton.addTarget(self, action: #selector(onBackTapped), for: .touchUpInside)
        // Solo hace falta si esta pantalla se puede cerrar hacia atrás —
        // si es la raíz (abierta desde el avatar de la top bar sin más
        // pantallas debajo en la pila), no hay a dónde volver.
        backButton.isHidden = navigationController?.viewControllers.first === self

        let kindLabel = UILabel()
        kindLabel.styleAsLabel(
            isOwnProfile ? "Tu perfil" : "Perfil", size: 12, medium: true,
            color: AppTheme.textSecondary(0.5), tracking: 1.4)

        let row = UIStackView(arrangedSubviews: [backButton, kindLabel])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])
        headerRow = row
    }

    private var headerRow: UIView!

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .header:
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(230))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            case .badges:
                guard self.hasBadgesContent else {
                    let emptySize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(0.01))
                    let emptyItem = NSCollectionLayoutItem(layoutSize: emptySize)
                    let emptyGroup = NSCollectionLayoutGroup.vertical(layoutSize: emptySize, subitems: [emptyItem])
                    return NSCollectionLayoutSection(group: emptyGroup)
                }
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(104))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let s = NSCollectionLayoutSection(group: group)
                s.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 20, trailing: 0)
                return s
            case .garage:
                guard self.hasGarageContent else {
                    let emptySize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(0.01))
                    let emptyItem = NSCollectionLayoutItem(layoutSize: emptySize)
                    let emptyGroup = NSCollectionLayoutGroup.vertical(layoutSize: emptySize, subitems: [emptyItem])
                    return NSCollectionLayoutSection(group: emptyGroup)
                }
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(180))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let s = NSCollectionLayoutSection(group: group)
                s.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 20, trailing: 0)
                return s
            case .routes:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(66))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let s = NSCollectionLayoutSection(group: group)
                s.interGroupSpacing = 9
                s.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0)
                if self.hasRoutesContent {
                    let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(28))
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                    s.boundarySupplementaryItems = [header]
                }
                return s
            }
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(RiderProfileHeaderCell.self, forCellWithReuseIdentifier: headerCellId)
        collectionView.register(RiderBadgesCell.self, forCellWithReuseIdentifier: badgesCellId)
        collectionView.register(RiderGarageCell.self, forCellWithReuseIdentifier: garageCellId)
        collectionView.register(RiderRouteRowCell.self, forCellWithReuseIdentifier: routeCellId)
        collectionView.register(
            SectionLabelHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionLabel")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private var hasGarageContent: Bool {
        isOwnProfile || profile?.currentMotorbike != nil
    }
    private var hasRoutesContent: Bool {
        (profile?.isVisible ?? false) && !(profile?.recentRoutes.isEmpty ?? true)
    }
    // Las insignias en sí nunca están "vacías" (el backend siempre
    // devuelve las 8, conseguidas o no — ver las que faltan es parte de
    // la gracia) — el único filtro es la misma visibilidad que ya rige
    // "Últimas rutas": datos derivados de actividad, mismas reglas de
    // privacidad para una cuenta que no sigues.
    private var hasBadgesContent: Bool {
        profile?.isVisible ?? false
    }

    private func reload() {
        guard let id = resolvedUserId else { return }
        Task {
            profile = try? await repository.profile(userId: id)
            if isOwnProfile {
                ownGarage = (try? await motorbikeRepository.getMotorbikes(userId: id)) ?? []
            }
            badges = (try? await badgesRepository.badges(userId: id)) ?? []
            collectionView.reloadData()
        }
    }

    private func onActionTapped() {
        guard let profile, let id = resolvedUserId else { return }
        Task {
            switch profile.followStatus {
            case "following", "pending":
                try? await repository.unfollow(userId: id)
            default:
                try? await repository.follow(userId: id)
            }
            reload()
        }
    }

    @objc private func onBackTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension RiderProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { Section.allCases.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .header: return 1
        case .badges: return hasBadgesContent ? 1 : 0
        case .garage: return hasGarageContent ? 1 : 0
        case .routes: return hasRoutesContent ? (profile?.recentRoutes.count ?? 0) : 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .header:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: headerCellId, for: indexPath) as! RiderProfileHeaderCell
            if let profile { cell.configure(with: profile) }
            cell.onActionTapped = { [weak self] in self?.onActionTapped() }
            return cell
        case .badges:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: badgesCellId, for: indexPath) as! RiderBadgesCell
            cell.configure(badges: badges)
            return cell
        case .garage:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: garageCellId, for: indexPath) as! RiderGarageCell
            if isOwnProfile {
                cell.configure(bikes: ownGarage, showsAddCard: true)
                cell.onAddTapped = { [weak self] in
                    guard let self else { return }
                    let form = AddMotorbikeViewController(editing: nil) { [weak self] in self?.reload() }
                    self.present(UINavigationController(rootViewController: form), animated: true)
                }
                cell.onBikeTapped = { [weak self] bike in
                    guard let self else { return }
                    let form = AddMotorbikeViewController(editing: bike) { [weak self] in self?.reload() }
                    self.present(UINavigationController(rootViewController: form), animated: true)
                }
            } else if let bike = profile?.currentMotorbike {
                // El perfil de otro rider solo expone la moto actual (no
                // todo el garaje ajeno) — se construye un MotorbikeModel
                // mínimo con lo que hay para reutilizar la misma celda.
                cell.configure(bikes: [MotorbikeModel(
                    id: bike.id, userId: resolvedUserId ?? 0, type: "", brand: "", model: bike.displayName,
                    cc: 0, alias: bike.alias, year: bike.year, photoUrl: bike.photoUrl, isCurrent: true)], showsAddCard: false)
            } else {
                cell.configure(bikes: [], showsAddCard: false)
            }
            return cell
        case .routes:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: routeCellId, for: indexPath) as! RiderRouteRowCell
            if let route = profile?.recentRoutes[indexPath.item] {
                cell.configure(with: route)
            }
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: "SectionLabel", for: indexPath) as! SectionLabelHeaderView
        view.configure(text: "Últimas rutas")
        return view
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .routes, let route = profile?.recentRoutes[indexPath.item] else { return }
        collectionView.deselectItem(at: indexPath, animated: true)
        let model = RouteModel(
            id: route.id, name: route.name, description: nil, authorId: resolvedUserId ?? 0,
            geojson: route.geojson, distanceKm: route.distanceKm,
            durationMinutes: route.durationMinutes, timesRidden: 0, coverImageUrl: route.coverImageUrl)
        navigationController?.pushViewController(RouteDetailViewController(route: model), animated: true)
    }
}

/// Etiqueta de sección reutilizable en mayúsculas ("Garaje", "Últimas
/// rutas"...) — el mismo estilo `AppFont.label` que usa el resto del
/// sistema para encabezar bloques de contenido.
final class SectionLabelHeaderView: UICollectionReusableView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(text: String) {
        label.styleAsLabel(text, size: 10.5, color: AppTheme.textSecondary(0.42), tracking: 1.4)
    }
}
