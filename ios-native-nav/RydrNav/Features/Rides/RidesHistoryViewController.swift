import UIKit

/// Espejo de lib/features/rides/presentation/rides_history_screen.dart.
final class RidesHistoryViewController: UIViewController {
    private let tableView = UITableView()
    private let repository = RideRepository()
    private var rides: [RideModel] = []
    private let cellId = "RideCell"

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy  HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mis rides"
        view.backgroundColor = AppTheme.bg0
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reload))

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppTheme.cardBorder
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        reload()
    }

    @objc private func reload() {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        Task {
            do {
                rides = try await repository.getRides(riderId: userId)
                    .sorted { $0.startedAt > $1.startedAt }
                tableView.reloadData()
            } catch {
                let alert = UIAlertController(
                    title: "Error al cargar", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func publishFlow(for ride: RideModel) {
        let publish = PublishRouteViewController(
            source: .existingRide(rideId: ride.id), pointCount: ride.trackPoints.count
        ) { [weak self] in
            self?.reload()
        }
        present(UINavigationController(rootViewController: publish), animated: true)
    }
}

extension RidesHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rides.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let ride = rides[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        var config = UIListContentConfiguration.subtitleCell()
        config.text = Self.dateFormatter.string(from: ride.startedAt)
        config.textProperties.font = AppFont.body(15, .semibold)
        config.textProperties.color = AppTheme.text
        let status = ride.isActive ? "En curso" : "Finalizado"
        config.secondaryText = "\(status) · \(ride.trackPoints.count) puntos"
        config.secondaryTextProperties.font = AppFont.body(13)
        config.secondaryTextProperties.color = AppTheme.textSecondary(0.5)
        cell.contentConfiguration = config
        cell.backgroundColor = .clear

        if !ride.isActive && !ride.trackPoints.isEmpty {
            let publish = UIButton(type: .system)
            publish.setTitle("Publicar", for: .normal)
            publish.setTitleColor(AppTheme.primary, for: .normal)
            publish.titleLabel?.font = AppFont.body(14, .semibold)
            publish.tag = indexPath.row
            publish.addTarget(self, action: #selector(onPublishTapped(_:)), for: .touchUpInside)
            publish.sizeToFit()
            cell.accessoryView = publish
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    @objc private func onPublishTapped(_ sender: UIButton) {
        publishFlow(for: rides[sender.tag])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
