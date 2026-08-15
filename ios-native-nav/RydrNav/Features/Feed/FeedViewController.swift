import UIKit

/// Portada de la app: feed de actividad con las rutas que han hecho los
/// riders a los que sigues, más recientes primero — primera pestaña del
/// shell (spec: "feed de actividad de mis amigos riders, las rutas que han
/// realizado").
final class FeedViewController: UIViewController {
    private let repository = RidersRepository()
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    private var items: [FeedItem] = []
    private let cellId = "FeedItem"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Actividad"
        view.backgroundColor = AppTheme.bg0
        installTopBar()
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
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.text = "Sigue a otros riders para ver aquí sus rutas"
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
        items = (try? await repository.feed()) ?? []
        collectionView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
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
