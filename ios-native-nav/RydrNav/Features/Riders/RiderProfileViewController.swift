import UIKit

/// Perfil social de un rider: foto grande, nombre, "Moto actual" y feed de
/// últimas rutas — espejo de "Perfil Social" (spec sección 3). `userId nil`
/// = el perfil propio (se abre pulsando el avatar de la top bar); cuentas
/// privadas que no sigues solo muestran la cabecera + botón de solicitud.
final class RiderProfileViewController: UIViewController {
    private let userId: Int?
    private let repository = RidersRepository()

    private var collectionView: UICollectionView!
    private var profile: RiderProfile?
    private let headerCellId = "Header"
    private let routeCellId = "RouteCard"

    private var resolvedUserId: Int? { userId ?? AuthManager.shared.currentUser?.id }

    init(userId: Int?) {
        self.userId = userId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = userId == nil ? "Mi perfil" : "Rider"
        view.backgroundColor = .systemBackground
        setupCollectionView()
        reload()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            if sectionIndex == 0 {
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(320))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(220))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(RiderProfileHeaderCell.self, forCellWithReuseIdentifier: headerCellId)
        collectionView.register(RouteCardCell.self, forCellWithReuseIdentifier: routeCellId)
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

    private func reload() {
        guard let id = resolvedUserId else { return }
        Task {
            profile = try? await repository.profile(userId: id)
            collectionView.reloadData()
        }
    }

    private func showAllMyRoutes() {
        guard let id = resolvedUserId else { return }
        let list = RouteListViewController(screenTitle: "Mis Rutas", showsTopBar: false) {
            try await RouteRepository().getRoutes(userId: id)
        }
        navigationController?.pushViewController(list, animated: true)
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
}

extension RiderProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let profile else { return section == 0 ? 1 : 0 }
        return section == 0 ? 1 : (profile.isVisible ? profile.recentRoutes.count : 0)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: headerCellId, for: indexPath) as! RiderProfileHeaderCell
            if let profile { cell.configure(with: profile) }
            cell.onActionTapped = { [weak self] in self?.onActionTapped() }
            cell.onViewAllRoutesTapped = { [weak self] in self?.showAllMyRoutes() }
            cell.onViewGarageTapped = { [weak self] in
                self?.navigationController?.pushViewController(MotorbikesViewController(showsTopBar: false), animated: true)
            }
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: routeCellId, for: indexPath) as! RouteCardCell
        if let route = profile?.recentRoutes[indexPath.item] {
            // RouteCardCell espera un RouteModel completo (usado también en
            // Rutas/Mis Rutas); aquí solo tenemos el resumen del feed, así
            // que se construye uno mínimo con los mismos campos que pinta
            // la tarjeta (no navega a detalle, así que el resto no importa).
            cell.configure(with: RouteModel(
                id: route.id, name: route.name, description: nil, authorId: resolvedUserId ?? 0,
                geojson: route.geojson, distanceKm: route.distanceKm,
                durationMinutes: route.durationMinutes, timesRidden: 0, coverImageUrl: route.coverImageUrl))
        }
        return cell
    }
}
