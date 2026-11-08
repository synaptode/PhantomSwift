#if DEBUG
import UIKit
import PhantomSwiftNetworking

// MARK: - NetworkListVC

/// Displays a list of captured network requests.
internal final class NetworkListVC: PhantomTableVC, PhantomEventObserver {
    private var allRequests: [PhantomRequest] = []
    private var filteredRequests: [PhantomRequest] = []
    private var searchText: String = ""
    private var activeFilter: String = "All"
    private var pendingRefreshWorkItem: DispatchWorkItem?
    private var refreshGeneration = 0
    private let refreshQueue = DispatchQueue(label: "com.phantomswift.network.list.refresh", qos: .userInitiated)

    // Filter header
    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private let statsLabel = UILabel()
    private var chips: [FilterChip] = []

    private let filterOptions = ["All", "GraphQL", "2xx", "3xx", "4xx", "5xx", "Pending", "Mocked"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network Trace"
        tableView.register(PhantomNetworkCell.self, forCellReuseIdentifier: "NetworkCell")
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        // Configure inherited searchBar
        searchBar.placeholder = "Search URL, host, or method…"
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = PhantomTheme.shared.surfaceColor
        }
        searchBar.delegate = self

        setupNavigation()
        setupFilterHeader()
        loadRequests()
        PhantomEventBus.shared.subscribe(self, to: "networkRequestCaptured")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            PhantomEventBus.shared.unsubscribe(self, from: "networkRequestCaptured")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFilterHeaderFrame()
    }

    deinit {
        PhantomEventBus.shared.unsubscribe(self, from: "networkRequestCaptured")
    }

    private func setupNavigation() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearLogs))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearLogs))
        }
        navigationItem.rightBarButtonItem?.tintColor = .systemRed
    }

    private func setupFilterHeader() {
        // Build a fixed-height header for chips + stats
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 54))
        headerView.backgroundColor = PhantomTheme.shared.backgroundColor

        chipScrollView.showsHorizontalScrollIndicator = false
        chipScrollView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(chipScrollView)

        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.addSubview(chipStack)

        statsLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statsLabel)

        for option in filterOptions {
            let chip = FilterChip(title: option)
            chip.isActive = option == activeFilter
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chips.append(chip)
            chipStack.addArrangedSubview(chip)
        }

        NSLayoutConstraint.activate([
            chipScrollView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 6),
            chipScrollView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            chipScrollView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            chipScrollView.heightAnchor.constraint(equalToConstant: 28),

            chipStack.topAnchor.constraint(equalTo: chipScrollView.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScrollView.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScrollView.leadingAnchor, constant: 16),
            chipStack.trailingAnchor.constraint(equalTo: chipScrollView.trailingAnchor, constant: -16),
            chipStack.heightAnchor.constraint(equalTo: chipScrollView.heightAnchor),

            statsLabel.topAnchor.constraint(equalTo: chipScrollView.bottomAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 18),
            statsLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -18),
        ])

        tableView.tableHeaderView = headerView
        updateFilterHeaderFrame()
    }

    private func updateFilterHeaderFrame() {
        guard let headerView = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        guard width > 0, headerView.frame.width != width else { return }

        var frame = headerView.frame
        frame.size.width = width
        headerView.frame = frame
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        tableView.tableHeaderView = headerView
    }

    // MARK: - Data

    private func loadRequests() {
        let generation = refreshGeneration + 1
        refreshGeneration = generation
        let search = searchText
        let filter = activeFilter

        refreshQueue.async { [weak self] in
            guard let self else { return }
            let requests = PhantomRequestStore.shared.getAll()
            let filtered = NetworkListVC.filteredRequests(from: requests, searchText: search, activeFilter: filter)
            DispatchQueue.main.async {
                guard self.refreshGeneration == generation else { return }
                self.allRequests = requests
                self.filteredRequests = filtered
                self.updateStats()
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        }
    }

    private func scheduleRefresh() {
        pendingRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingRefreshWorkItem = nil
            self?.loadRequests()
        }
        pendingRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    static func filteredRequests(from requests: [PhantomRequest], searchText: String, activeFilter: String) -> [PhantomRequest] {
        var result = requests

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.url.absoluteString.lowercased().contains(query) ||
                $0.method.lowercased().contains(query) ||
                ($0.url.host?.lowercased().contains(query) ?? false) ||
                (PhantomGraphQLParser.parse(request: $0)?.displayName.lowercased().contains(query) ?? false)
            }
        }

        switch activeFilter {
        case "GraphQL":
            result = result.filter { PhantomGraphQLParser.isGraphQL(request: $0) }
        case "2xx": result = result.filter { ($0.response?.statusCode ?? 0).between(200, 299) }
        case "4xx": result = result.filter { ($0.response?.statusCode ?? 0).between(400, 499) }
        case "5xx": result = result.filter { ($0.response?.statusCode ?? 0).between(500, 599) }
        case "Pending":
            result = result.filter { if case .pending = $0.status { return true }; return false }
        case "Mocked":
            result = result.filter { if case .mocked = $0.status { return true }; return false }
        default: break
        }

        return result
    }

    private func updateStats() {
        let total = allRequests.count
        let errors = allRequests.filter { ($0.response?.statusCode ?? 0) >= 400 }.count
        let pending = allRequests.filter { if case .pending = $0.status { return true }; return false }.count
        if total == 0 {
            statsLabel.text = "No requests captured yet"
        } else {
            var parts = ["\(total) request\(total == 1 ? "" : "s")"]
            if errors > 0 { parts.append("\(errors) error\(errors == 1 ? "" : "s")") }
            if pending > 0 { parts.append("\(pending) pending") }
            statsLabel.text = parts.joined(separator: " · ")
        }
    }

    private let emptyView = PhantomEmptyStateView(symbolName: "antenna.radiowaves.left.and.right", title: "No Requests", message: "Network traffic will appear here automatically.")

    private func updateEmptyState() {
        if filteredRequests.isEmpty {
            if emptyView.superview == nil {
                emptyView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(emptyView)
                NSLayoutConstraint.activate([
                    emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
                ])
            }
        } else {
            emptyView.removeFromSuperview()
        }
    }

    @objc private func clearLogs() {
        pendingRefreshWorkItem?.cancel()
        pendingRefreshWorkItem = nil
        PhantomRequestStore.shared.clear()
        loadRequests()
    }

    @objc private func chipTapped(_ sender: FilterChip) {
        activeFilter = sender.title
        chips.forEach { $0.isActive = $0.title == activeFilter }
        scheduleRefresh()
    }

    // MARK: - PhantomEventObserver

    func onEvent(_ event: PhantomEvent) {
        if case .networkRequestCaptured = event {
            scheduleRefresh()
        }
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRequests.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let request = filteredRequests[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NetworkCell", for: indexPath) as? PhantomNetworkCell else {
            return UITableViewCell()
        }
        cell.configure(with: request)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let request = filteredRequests[indexPath.row]
        let detailVC = RequestDetailVC(request: request)
        navigationController?.pushViewController(detailVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension NetworkListVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        scheduleRefresh()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - Quick Actions

extension NetworkListVC {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let request = filteredRequests[indexPath.row]

        let blockAction = UIContextualAction(style: .destructive, title: "Block") { [weak self] _, _, done in
            self?.openRuleEditor(with: .block(for: request))
            done(true)
        }
        blockAction.backgroundColor = UIColor.Phantom.vibrantRed

        let delayAction = UIContextualAction(style: .normal, title: "Delay") { [weak self] _, _, done in
            self?.openRuleEditor(with: .delay(for: request))
            done(true)
        }
        delayAction.backgroundColor = UIColor.Phantom.vibrantOrange

        let swipeActions: [UIContextualAction]
        if request.response != nil {
            let mockAction = UIContextualAction(style: .normal, title: "Mock") { [weak self] _, _, done in
                self?.openRuleEditor(with: .mock(from: request))
                done(true)
            }
            mockAction.backgroundColor = UIColor.Phantom.vibrantPurple
            swipeActions = [blockAction, delayAction, mockAction]
        } else {
            swipeActions = [blockAction, delayAction]
        }

        let configuration = UISwipeActionsConfiguration(actions: swipeActions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let request = filteredRequests[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu() }

            var children: [UIMenuElement] = [
                UIAction(title: "Open Detail", image: UIImage(systemName: "arrow.right.circle")) { _ in
                    let detailVC = RequestDetailVC(request: request)
                    self.navigationController?.pushViewController(detailVC, animated: true)
                },
                UIAction(title: "Create Block Rule", image: UIImage(systemName: "hand.raised.fill")) { _ in
                    self.openRuleEditor(with: .block(for: request))
                },
                UIAction(title: "Create Delay Rule", image: UIImage(systemName: "clock.badge.exclamationmark")) { _ in
                    self.openRuleEditor(with: .delay(for: request))
                },
                UIAction(title: "Create Redirect Rule", image: UIImage(systemName: "arrow.triangle.swap")) { _ in
                    self.openRuleEditor(with: .redirect(for: request))
                }
            ]

            if request.response != nil {
                children.insert(
                    UIAction(title: "Create Mock Rule", image: UIImage(systemName: "sparkles.rectangle.stack")) { _ in
                        self.openRuleEditor(with: .mock(from: request))
                    },
                    at: 3
                )
            }

            return UIMenu(title: "", children: children)
        }
    }

    private func openRuleEditor(with draft: PhantomInterceptorDraft) {
        let editor = RuleEditorVC(draft: draft)
        navigationController?.pushViewController(editor, animated: true)
    }
}

// MARK: - Helpers

private extension Int {
    func between(_ lower: Int, _ upper: Int) -> Bool { self >= lower && self <= upper }
}
#endif
