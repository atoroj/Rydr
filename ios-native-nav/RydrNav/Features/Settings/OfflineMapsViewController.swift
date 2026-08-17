import UIKit

/// Lista de zonas descargadas para navegar sin conexión — mapa + carreteras
/// de la zona de cada ruta guardada desde `RouteDetailViewController`.
/// Espejo simple de `RidesHistoryViewController` (mismo patrón de
/// `UITableView` con `UIListContentConfiguration`).
final class OfflineMapsViewController: UIViewController {
    private struct Row {
        let regionId: String
        let title: String
        let sizeBytes: UInt64
    }

    private let tableView = UITableView()
    private let emptyLabel = UILabel()
    private var rows: [Row] = []
    private let cellId = "OfflineRegionCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mapas sin conexión"
        view.backgroundColor = AppTheme.bg0

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppTheme.cardBorder
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyLabel.text = "Todavía no has descargado ninguna zona.\nEntra en una ruta y toca \"Guardar sin conexión\"."
        emptyLabel.font = AppFont.body(14)
        emptyLabel.textColor = AppTheme.textSecondary(0.5)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        Task { await reload() }
    }

    private func reload() async {
        let regions = await OfflineMapManager.shared.downloadedRegions()
        var newRows: [Row] = []
        for region in regions {
            newRows.append(Row(regionId: region.id, title: await routeName(for: region.id), sizeBytes: region.completedResourceSize))
        }
        rows = newRows.sorted { $0.title < $1.title }
        tableView.reloadData()
        emptyLabel.isHidden = !rows.isEmpty
    }

    /// El id de la región es "route-<id>" (ver `OfflineMapManager.regionId`)
    /// — se resuelve contra el backend para enseñar el nombre real de la
    /// ruta en vez de un identificador críptico. Si falla (ruta borrada,
    /// sin red) cae al propio id, no deja la fila en blanco.
    private func routeName(for regionId: String) async -> String {
        guard let routeId = Int(regionId.replacingOccurrences(of: "route-", with: "")),
              let route = try? await RouteRepository().getRoute(id: routeId)
        else { return regionId }
        return route.name
    }

    private func delete(at indexPath: IndexPath) {
        let row = rows[indexPath.row]
        Task {
            await OfflineMapManager.shared.delete(regionId: row.regionId)
            await reload()
        }
    }
}

extension OfflineMapsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        var config = UIListContentConfiguration.subtitleCell()
        config.text = row.title
        config.textProperties.font = AppFont.body(15, .semibold)
        config.textProperties.color = AppTheme.text
        config.secondaryText = ByteCountFormatter.string(fromByteCount: Int64(row.sizeBytes), countStyle: .file)
        config.secondaryTextProperties.font = AppFont.body(13)
        config.secondaryTextProperties.color = AppTheme.textSecondary(0.5)
        cell.contentConfiguration = config
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        delete(at: indexPath)
    }
}
