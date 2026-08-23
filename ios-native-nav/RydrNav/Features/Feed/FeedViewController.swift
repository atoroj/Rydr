import CoreLocation
import UIKit

/// Portada de la app: feed de actividad, con dos pestañas — "Siguiendo"
/// (rutas de la gente que sigues, como antes) y "Cerca de ti" (rutas
/// públicas de cualquiera, ordenadas por cercanía a tu posición actual).
/// Mismo patrón de interruptor que `RidersViewController` (Siguiendo/
/// Seguidores/Solicitudes).
final class FeedViewController: UIViewController {
    private enum Mode: Int { case following, nearby }

    private let repository = RidersRepository()
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private let segmented = UISegmentedControl(items: ["Siguiendo", "Cerca de ti"])
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    private var items: [FeedItem] = []
    private let cellId = "FeedItem"

    private var currentMode: Mode { Mode(rawValue: segmented.selectedSegmentIndex) ?? .following }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Actividad"
        view.backgroundColor = AppTheme.bg0
        locationManager.delegate = self
        installTopBar()
        setupSegmented()
        setupCollectionView()
        setupEmptyLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func setupSegmented() {
        segmented.selectedSegmentIndex = 0
        segmented.backgroundColor = AppTheme.bg2
        segmented.selectedSegmentTintColor = AppTheme.bg3
        segmented.setTitleTextAttributes([.foregroundColor: AppTheme.textSecondary(0.6)], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: AppTheme.text], for: .selected)
        segmented.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmented)
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .estimated(240))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(FeedItemCell.self, forCellWithReuseIdentifier: cellId)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refresh

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.font = AppFont.body(15)
        emptyLabel.textColor = AppTheme.textSecondary(0.5)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    @objc private func onSegmentChanged() {
        reload()
    }

    @objc private func onPullToRefresh() {
        Task {
            await load()
            collectionView.refreshControl?.endRefreshing()
        }
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        switch currentMode {
        case .following:
            emptyLabel.text = "Sigue a otros riders para ver aquí sus rutas"
            items = (try? await repository.feed()) ?? []
            collectionView.reloadData()
            emptyLabel.isHidden = !items.isEmpty

        case .nearby:
            guard let coordinate = await currentLocation() else {
                items = []
                collectionView.reloadData()
                emptyLabel.text = "Activa la ubicación para ver rutas públicas cerca de ti"
                emptyLabel.isHidden = false
                return
            }
            emptyLabel.text = "No hay rutas públicas cerca de ti todavía"
            items = (try? await repository.nearbyFeed(lat: coordinate.latitude, lng: coordinate.longitude)) ?? []
            collectionView.reloadData()
            emptyLabel.isHidden = !items.isEmpty
        }
    }

    // MARK: - Posición actual (una sola vez, al entrar en "Cerca de ti")

    private func currentLocation() async -> CLLocationCoordinate2D? {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        guard locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
        else { return nil }

        if let cached = locationManager.location?.coordinate { return cached }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
}

extension FeedViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! FeedItemCell
        let item = items[indexPath.item]
        cell.configure(with: item)
        cell.onAuthorTapped = { [weak self] in
            self?.navigationController?.pushViewController(RiderProfileViewController(userId: item.author.id), animated: true)
        }
        // La tarjeta lleva su propio UIButton de fondo (para que el de
        // autor, encima, pueda robarle el toque en la cabecera) — por eso
        // la navegación va por aquí y no por didSelectItemAt, que no llega
        // a dispararse cuando el toque lo recoge un UIButton.
        cell.onOpenTapped = { [weak self] in self?.openRoute(item) }
        return cell
    }

    private func openRoute(_ item: FeedItem) {
        // FeedItem trae un resumen de la ruta (sin descripción, que el feed
        // no necesita); se arma un RouteModel mínimo para reutilizar
        // RouteDetailViewController tal cual.
        let route = RouteModel(
            id: item.route.id, name: item.route.name, description: nil, authorId: item.author.id,
            geojson: item.route.geojson, distanceKm: item.route.distanceKm,
            durationMinutes: item.route.durationMinutes, timesRidden: 0, coverImageUrl: item.route.coverImageUrl)
        navigationController?.pushViewController(RouteDetailViewController(route: route), animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension FeedViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last?.coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
