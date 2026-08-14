import UIKit

/// "Quedadas": organizar rutas con compañeros — privadas (solo tus Riders)
/// o públicas (se apunta quien quiera), con aforo y descripción. Ocupa el
/// sitio que tenía "Mis Motos" en el shell (spec del usuario).
final class MeetupsViewController: UIViewController {
    private enum Segment: Int { case discover, mine }

    private let repository = MeetupsRepository()
    private let segmented = UISegmentedControl(items: ["Descubrir", "Mis quedadas"])
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    private let cellId = "MeetupCard"

    private var discoverItems: [Meetup] = []
    private var mineItems: [Meetup] = []
    private var currentSegment: Segment { Segment(rawValue: segmented.selectedSegmentIndex) ?? .discover }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Quedadas"
        view.backgroundColor = .systemBackground
        installTopBar()
        let addItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(onAddTapped))
        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem, addItem].compactMap { $0 }

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
                widthDimension: .fractionalWidth(1), heightDimension: .estimated(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(MeetupCardCell.self, forCellWithReuseIdentifier: cellId)
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
        emptyLabel.textColor = .secondaryLabel
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
        updateEmptyState()
        collectionView.reloadData()
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
        async let d: [Meetup]? = try? repository.discover()
        async let m: [Meetup]? = try? repository.mine()
        discoverItems = await d ?? []
        mineItems = await m ?? []
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let items = currentSegment == .discover ? discoverItems : mineItems
        emptyLabel.text = currentSegment == .discover
            ? "No hay quedadas cerca. ¡Organiza tú la primera!"
            : "No organizas ni te has apuntado a ninguna quedada todavía"
        emptyLabel.isHidden = !items.isEmpty
    }

    @objc private func onAddTapped() {
        let createVC = CreateMeetupViewController(editing: nil) { [weak self] in self?.reload() }
        present(UINavigationController(rootViewController: createVC), animated: true)
    }

    private func toggleParticipation(_ meetup: Meetup) {
        Task {
            do {
                if meetup.isJoined {
                    try await repository.leave(id: meetup.id)
                } else {
                    try await repository.join(id: meetup.id)
                }
                await load()
            } catch {
                let alert = UIAlertController(title: "Vaya", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

extension MeetupsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    private var items: [Meetup] { currentSegment == .discover ? discoverItems : mineItems }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! MeetupCardCell
        let meetup = items[indexPath.item]
        cell.configure(with: meetup)
        cell.onActionTapped = { [weak self] in self?.toggleParticipation(meetup) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let detail = MeetupDetailViewController(meetup: items[indexPath.item]) { [weak self] in self?.reload() }
        navigationController?.pushViewController(detail, animated: true)
    }
}
