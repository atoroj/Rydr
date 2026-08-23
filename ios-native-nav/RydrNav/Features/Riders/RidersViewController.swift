import UIKit

/// Sección social "Riders" — espejo del listado "Amigos" del spec (sección
/// 3): buscador + Siguiendo / Seguidores / Solicitudes pendientes, cada
/// fila con avatar, nombre y la moto que conduce actualmente.
final class RidersViewController: UIViewController {
    private enum Segment: Int { case following, followers, requests }

    private let repository = RidersRepository()
    private let segmented = UISegmentedControl(items: ["Siguiendo", "Seguidores", "Solicitudes"])
    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private let cellId = "RiderRow"

    private var following: [RiderSummary] = []
    private var followers: [RiderSummary] = []
    private var requests: [FollowRequest] = []
    private var searchResults: [RiderSummary] = []

    private var currentSegment: Segment { Segment(rawValue: segmented.selectedSegmentIndex) ?? .following }
    private var isSearching: Bool { !(searchController.searchBar.text ?? "").isEmpty }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Riders"
        view.backgroundColor = AppTheme.bg0
        installTopBar()
        setupSearch()
        setupSegmented()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAll()
    }

    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Buscar riders"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
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

    private func setupTableView() {
        tableView.register(RiderRowCell.self, forCellReuseIdentifier: cellId)
        tableView.backgroundColor = .clear
        // Cada fila es su propia tarjeta con borde (ver RiderRowCell) — el
        // separador de línea del sistema sobraría.
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 75
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func onSegmentChanged() {
        tableView.reloadData()
    }

    private func reloadAll() {
        Task {
            async let f: [RiderSummary]? = try? repository.following()
            async let fl: [RiderSummary]? = try? repository.followers()
            async let r: [FollowRequest]? = try? repository.pendingRequests()
            following = await f ?? []
            followers = await fl ?? []
            requests = await r ?? []
            tableView.reloadData()
        }
    }

    private func performSearch(_ query: String) {
        Task {
            searchResults = (try? await repository.search(query: query)) ?? []
            tableView.reloadData()
        }
    }

    /// Texto del botón principal de una fila según la relación con ese
    /// rider; `nil` implícito (cadena vacía) para "self", que oculta el botón.
    private func primaryTitle(for status: String) -> String {
        switch status {
        case "following": return "Siguiendo"
        case "pending": return "Pendiente"
        case "self": return ""
        default: return "Seguir"
        }
    }

    private func toggleFollow(_ rider: RiderSummary) {
        Task {
            if rider.followStatus == "following" || rider.followStatus == "pending" {
                try? await repository.unfollow(userId: rider.id)
            } else {
                try? await repository.follow(userId: rider.id)
            }
            reloadAll()
            if isSearching { performSearch(searchController.searchBar.text ?? "") }
        }
    }

    private func accept(_ request: FollowRequest) {
        Task {
            try? await repository.accept(requestId: request.id)
            reloadAll()
        }
    }

    private func reject(_ request: FollowRequest) {
        Task {
            try? await repository.reject(requestId: request.id)
            reloadAll()
        }
    }
}

extension RidersViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        if query.isEmpty {
            searchResults = []
            tableView.reloadData()
        } else {
            performSearch(query)
        }
    }
}

extension RidersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching { return searchResults.count }
        switch currentSegment {
        case .following: return following.count
        case .followers: return followers.count
        case .requests: return requests.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! RiderRowCell

        if isSearching {
            let rider = searchResults[indexPath.row]
            let title = primaryTitle(for: rider.followStatus)
            cell.configure(rider: rider, primaryTitle: title.isEmpty ? nil : title)
            cell.onPrimaryTapped = { [weak self] in self?.toggleFollow(rider) }
            return cell
        }

        switch currentSegment {
        case .following:
            let rider = following[indexPath.row]
            cell.configure(rider: rider, primaryTitle: "Dejar de seguir")
            cell.onPrimaryTapped = { [weak self] in self?.toggleFollow(rider) }
        case .followers:
            let rider = followers[indexPath.row]
            let title = primaryTitle(for: rider.followStatus)
            cell.configure(rider: rider, primaryTitle: title.isEmpty ? nil : title)
            cell.onPrimaryTapped = { [weak self] in self?.toggleFollow(rider) }
        case .requests:
            let request = requests[indexPath.row]
            cell.configure(rider: request.fromUser, primaryTitle: "Aceptar", showReject: true)
            cell.onPrimaryTapped = { [weak self] in self?.accept(request) }
            cell.onRejectTapped = { [weak self] in self?.reject(request) }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let userId: Int
        if isSearching {
            userId = searchResults[indexPath.row].id
        } else {
            switch currentSegment {
            case .following: userId = following[indexPath.row].id
            case .followers: userId = followers[indexPath.row].id
            case .requests: userId = requests[indexPath.row].fromUser.id
            }
        }
        navigationController?.pushViewController(RiderProfileViewController(userId: userId), animated: true)
    }
}
