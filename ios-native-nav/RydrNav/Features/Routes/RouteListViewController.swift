import UIKit

/// Listado de rutas en tarjetas — generaliza lo que antes era
/// `RoutesListViewController` para servir tanto a "Rutas" (públicas) como
/// a "Mis Rutas" (del usuario), inyectando qué traer por closure en vez de
/// duplicar la pantalla entera. Espejo de `RoutesScreen`
/// (lib/features/routes/presentation/routes_screen.dart).
final class RouteListViewController: UIViewController {
    private let screenTitle: String
    private let fetch: () async throws -> [RouteModel]
    private let showsTopBar: Bool

    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    private var routes: [RouteModel] = []
    private let cellId = "RouteCard"

    /// [showsTopBar] es `false` cuando esta pantalla se empuja desde otra
    /// (p. ej. "Ver todas mis rutas" en el perfil propio) en vez de ser la
    /// raíz de una pestaña del shell — ahí ya hay un back button normal de
    /// `UINavigationController`, no hace falta la barra de avatar+ajustes.
    init(screenTitle: String, showsTopBar: Bool = true, fetch: @escaping () async throws -> [RouteModel]) {
        self.screenTitle = screenTitle
        self.showsTopBar = showsTopBar
        self.fetch = fetch
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = screenTitle
        view.backgroundColor = .systemBackground
        if showsTopBar { installTopBar() }
        setupCollectionView()
        setupEmptyLabel()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Recarga cada vez que se muestra: por ejemplo, tras publicar una
        // ruta nueva desde Registrar, "Mis Rutas" debe reflejarla al volver.
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
        collectionView.register(RouteCardCell.self, forCellWithReuseIdentifier: cellId)
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
        emptyLabel.text = "Todavía no hay rutas aquí"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
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
        do {
            routes = try await fetch()
            collectionView.reloadData()
            emptyLabel.isHidden = !routes.isEmpty
        } catch {
            let alert = UIAlertController(
                title: "No se pudieron cargar las rutas", message: error.localizedDescription,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

extension RouteListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        routes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! RouteCardCell
        cell.configure(with: routes[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        navigationController?.pushViewController(RouteDetailViewController(route: routes[indexPath.item]), animated: true)
    }
}
