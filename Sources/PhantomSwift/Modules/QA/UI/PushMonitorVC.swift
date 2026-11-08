#if DEBUG
import UIKit
import UserNotifications

/// Real-time monitor view controller for inspecting incoming push and local notifications.
internal final class PushMonitorVC: UIViewController, PhantomEventObserver {

    private let tokenCard = UIView()
    private let tokenTitleLabel = UILabel()
    private let tokenValueLabel = UILabel()
    private let tokenCopyButton = UIButton(type: .system)

    private let filterControl = UISegmentedControl(items: ["All", "Remote", "Local", "Simulated"])
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = PhantomEmptyStateView(
        symbolName: "bell.badge",
        title: "No Notifications Captured",
        message: "Incoming APNs remote notifications and local notifications will be intercepted here live."
    )

    private var allRecords: [PhantomPushRecord] = []
    private var filteredRecords: [PhantomPushRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Live Monitor"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigation()
        setupTokenCard()
        setupControls()
        setupTableView()
        setupConstraints()

        reloadRecords()
        updateTokenDisplay()

        PhantomEventBus.shared.subscribe(self, to: "pushNotificationCaptured")
        PhantomEventBus.shared.subscribe(self, to: "apnsTokenUpdated")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadRecords()
        updateTokenDisplay()
    }

    deinit {
        PhantomEventBus.shared.unsubscribe(self, from: "pushNotificationCaptured")
        PhantomEventBus.shared.unsubscribe(self, from: "apnsTokenUpdated")
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(didTapClear)
        )
    }

    private func setupTokenCard() {
        tokenCard.backgroundColor = PhantomTheme.shared.surfaceColor
        tokenCard.layer.cornerRadius = 10
        tokenCard.layer.borderWidth = 1
        tokenCard.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        tokenCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenCard)

        tokenTitleLabel.text = "APNs Device Token"
        tokenTitleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        tokenTitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        tokenTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        tokenCard.addSubview(tokenTitleLabel)

        tokenValueLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        tokenValueLabel.textColor = PhantomTheme.shared.textColor
        tokenValueLabel.lineBreakMode = .byTruncatingMiddle
        tokenValueLabel.translatesAutoresizingMaskIntoConstraints = false
        tokenCard.addSubview(tokenValueLabel)

        tokenCopyButton.setTitle("Copy", for: .normal)
        tokenCopyButton.setImage(UIImage.phantomSymbol("doc.on.doc"), for: .normal)
        tokenCopyButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        tokenCopyButton.tintColor = PhantomTheme.shared.accentColor
        tokenCopyButton.addTarget(self, action: #selector(didTapCopyToken), for: .touchUpInside)
        tokenCopyButton.translatesAutoresizingMaskIntoConstraints = false
        tokenCard.addSubview(tokenCopyButton)
    }

    private func setupControls() {
        filterControl.selectedSegmentIndex = 0
        filterControl.applyPhantomStyle()
        filterControl.addTarget(self, action: #selector(didChangeFilter), for: .valueChanged)
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterControl)

        searchBar.placeholder = "Filter notifications..."
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 96
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PushMonitorCell.self, forCellReuseIdentifier: "PushMonitorCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tokenCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            tokenCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            tokenCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            tokenCard.heightAnchor.constraint(equalToConstant: 54),

            tokenTitleLabel.topAnchor.constraint(equalTo: tokenCard.topAnchor, constant: 8),
            tokenTitleLabel.leadingAnchor.constraint(equalTo: tokenCard.leadingAnchor, constant: 12),

            tokenValueLabel.topAnchor.constraint(equalTo: tokenTitleLabel.bottomAnchor, constant: 4),
            tokenValueLabel.leadingAnchor.constraint(equalTo: tokenCard.leadingAnchor, constant: 12),
            tokenValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: tokenCopyButton.leadingAnchor, constant: -8),

            tokenCopyButton.centerYAnchor.constraint(equalTo: tokenCard.centerYAnchor),
            tokenCopyButton.trailingAnchor.constraint(equalTo: tokenCard.trailingAnchor, constant: -12),

            filterControl.topAnchor.constraint(equalTo: tokenCard.bottomAnchor, constant: 10),
            filterControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            filterControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            searchBar.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 6),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateTokenDisplay() {
        if let token = PhantomPushStore.shared.apnsToken, !token.isEmpty {
            tokenValueLabel.text = token
            tokenCopyButton.isEnabled = true
        } else {
            tokenValueLabel.text = "No APNs token registered yet"
            tokenCopyButton.isEnabled = false
        }
    }

    private func reloadRecords() {
        allRecords = PhantomPushStore.shared.getAll()
        applyFilter()
    }

    private func applyFilter() {
        let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let filterIndex = filterControl.selectedSegmentIndex

        filteredRecords = allRecords.filter { record in
            let matchesType: Bool
            switch filterIndex {
            case 1: matchesType = record.source == .remote
            case 2: matchesType = record.source == .local
            case 3: matchesType = record.source == .simulated
            default: matchesType = true
            }

            guard matchesType else { return false }
            guard !query.isEmpty else { return true }

            return record.title.lowercased().contains(query)
                || record.body.lowercased().contains(query)
                || record.identifier.lowercased().contains(query)
        }

        emptyStateView.isHidden = !filteredRecords.isEmpty
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func didChangeFilter() {
        applyFilter()
    }

    @objc private func didTapClear() {
        PhantomPushStore.shared.clear()
        reloadRecords()
    }

    @objc private func didTapCopyToken() {
        guard let token = PhantomPushStore.shared.apnsToken else { return }
        UIPasteboard.general.string = token
        let alert = UIAlertController(title: "Copied", message: "APNs Device Token copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - PhantomEventObserver

    func onEvent(_ event: PhantomEvent) {
        DispatchQueue.main.async { [weak self] in
            switch event {
            case .pushNotificationCaptured:
                self?.reloadRecords()
            case .apnsTokenUpdated:
                self?.updateTokenDisplay()
            default:
                break
            }
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension PushMonitorVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredRecords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "PushMonitorCell",
            for: indexPath
        ) as? PushMonitorCell else {
            return UITableViewCell()
        }
        cell.configure(with: filteredRecords[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = filteredRecords[indexPath.row]
        let detailVC = PushDetailVC(record: record)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension PushMonitorVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
#endif
