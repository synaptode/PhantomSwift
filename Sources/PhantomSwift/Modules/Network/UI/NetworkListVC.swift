#if DEBUG
import UIKit

// MARK: - Filter Chip

private final class FilterChip: UIControl {
    let title: String
    private let label = UILabel()

    var isActive: Bool = false {
        didSet { updateAppearance() }
    }

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        if isActive {
            backgroundColor = PhantomTheme.shared.primaryColor
            layer.borderColor = PhantomTheme.shared.primaryColor.cgColor
            label.textColor = .white
        } else {
            backgroundColor = PhantomTheme.shared.surfaceColor
            layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1.0 }
    }
}

// MARK: - NetworkListVC

/// Displays a list of captured network requests.
internal final class NetworkListVC: PhantomTableVC, PhantomEventObserver {
    private var allRequests: [PhantomRequest] = []
    private var filteredRequests: [PhantomRequest] = []
    private var searchText: String = ""
    private var activeFilter: String = "All"

    // Filter header
    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private let statsLabel = UILabel()
    private var chips: [FilterChip] = []

    private let filterOptions = ["All", "2xx", "3xx", "4xx", "5xx", "Pending", "Mocked"]

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
        if isMovingFromParent {
            PhantomEventBus.shared.unsubscribe(self, from: "networkRequestCaptured")
        }
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
    }

    // MARK: - Data

    private func loadRequests() {
        allRequests = PhantomRequestStore.shared.getAll()
        applyFilters()
    }

    private func applyFilters() {
        var result = allRequests

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.url.absoluteString.lowercased().contains(q) ||
                $0.method.lowercased().contains(q) ||
                ($0.url.host?.lowercased().contains(q) ?? false)
            }
        }

        switch activeFilter {
        case "2xx": result = result.filter { ($0.response?.statusCode ?? 0).between(200, 299) }
        case "3xx": result = result.filter { ($0.response?.statusCode ?? 0).between(300, 399) }
        case "4xx": result = result.filter { ($0.response?.statusCode ?? 0).between(400, 499) }
        case "5xx": result = result.filter { ($0.response?.statusCode ?? 0).between(500, 599) }
        case "Pending":
            result = result.filter { if case .pending = $0.status { return true }; return false }
        case "Mocked":
            result = result.filter { if case .mocked = $0.status { return true }; return false }
        default: break
        }

        filteredRequests = result
        updateStats()
        tableView.reloadData()
        updateEmptyState()
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

    private let emptyView = PhantomEmptyStateView(emoji: "📡", title: "No Requests", message: "Network traffic will appear here automatically.")

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
        PhantomRequestStore.shared.clear()
        loadRequests()
    }

    @objc private func chipTapped(_ sender: FilterChip) {
        activeFilter = sender.title
        chips.forEach { $0.isActive = $0.title == activeFilter }
        applyFilters()
    }

    // MARK: - PhantomEventObserver

    func onEvent(_ event: PhantomEvent) {
        if case .networkRequestCaptured(let request) = event {
            allRequests.insert(request, at: 0)
            applyFilters()
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
        applyFilters()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - Helpers

private extension Int {
    func between(_ lo: Int, _ hi: Int) -> Bool { self >= lo && self <= hi }
}



/// Displays detailed information about a specific network request.
internal final class RequestDetailVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let request: PhantomRequest
    private let headerView = PhantomNetworkHeaderView()
    private let segmentedControl = UISegmentedControl(items: ["Overview", "Headers", "Body"])
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let codeView = PhantomCodeView()
    
    private var sections: [(title: String, rows: [(key: String, value: String)])] = []
    
    init(request: PhantomRequest) {
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        showOverview()
    }
    
    private func setupNavigation() {
        let actionItem: UIBarButtonItem
        if #available(iOS 14.0, *) {
            let menu = UIMenu(title: "Request Actions", children: [
                UIAction(title: "Copy to Clipboard", image: UIImage(systemName: "doc.on.doc"), handler: { [weak self] _ in self?.copyToClipboard() }),
                UIAction(title: "Copy as cURL", image: UIImage(systemName: "terminal"), handler: { [weak self] _ in self?.copyAsCURL() }),
                UIAction(title: "Export as HAR", image: UIImage(systemName: "square.and.arrow.up"), handler: { [weak self] _ in self?.exportAsHAR() }),
                UIAction(title: "Edit & Mock", image: UIImage(systemName: "pencil.and.outline"), handler: { [weak self] _ in self?.editAndMock() })
            ])
            actionItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        } else if #available(iOS 13.0, *) {
            actionItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(showActionSheet))
        } else {
            actionItem = UIBarButtonItem(title: "Options", style: .plain, target: self, action: #selector(showActionSheet))
        }
        navigationItem.rightBarButtonItem = actionItem
    }
    
    @objc private func showActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "📋 Copy to Clipboard", style: .default, handler: { [weak self] _ in self?.copyToClipboard() }))
        alert.addAction(UIAlertAction(title: "⌨️ Copy as cURL", style: .default, handler: { [weak self] _ in self?.copyAsCURL() }))
        alert.addAction(UIAlertAction(title: "📤 Export as HAR", style: .default, handler: { [weak self] _ in self?.exportAsHAR() }))
        alert.addAction(UIAlertAction(title: "✍️ Edit & Mock", style: .default, handler: { [weak self] _ in self?.editAndMock() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }
    
    @objc private func copyToClipboard() {
        let contentToCopy: String?
        if segmentedControl.selectedSegmentIndex == 2 {
            contentToCopy = codeView.text
        } else {
            contentToCopy = sections.map { section in
                "\(section.title)\n" + section.rows.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            }.joined(separator: "\n\n")
        }

        UIPasteboard.general.string = contentToCopy
        let alert = UIAlertController(title: "Copied", message: "Content copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func copyAsCURL() {
        let curl = PhantomCURLExporter.export(from: request)
        UIPasteboard.general.string = curl
        let alert = UIAlertController(title: "Copied", message: "cURL command copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func exportAsHAR() {
        PhantomHARExporter.shared.export(from: self, request: request)
    }
    
    
    @objc private func editAndMock() {
        let editor = PhantomMockEditorVC(request: self.request)
        navigationController?.pushViewController(editor, animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Request Detail"
        
        headerView.configure(with: request)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.applyPhantomStyle()
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.05)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DetailCell.self, forCellReuseIdentifier: "DetailCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        codeView.isHidden = true
        codeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 15),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            codeView.topAnchor.constraint(equalTo: tableView.topAnchor),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            codeView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        ])
    }
    
    @objc private func segmentChanged() {
        tableView.isHidden = segmentedControl.selectedSegmentIndex == 2
        codeView.isHidden = segmentedControl.selectedSegmentIndex != 2
        
        switch segmentedControl.selectedSegmentIndex {
        case 0: showOverview()
        case 1: showHeaders()
        case 2: showBody()
        default: break
        }
    }
    
    private func showOverview() {
        var rows: [(key: String, value: String)] = [
            ("URL", request.url.absoluteString),
            ("Method", request.method),
            ("Time", "\(request.timestamp)")
        ]

        if let response = request.response {
            rows.append(("Status", "\(response.statusCode)"))
            rows.append(("Duration", String(format: "%.3f s", response.duration)))
            let size = ByteCountFormatter.string(fromByteCount: Int64(response.body?.count ?? 0), countStyle: .file)
            rows.append(("Size", size))
        }

        var allSections = [("General", rows)]

        // If this was a Mockoon redirect, show a dedicated section
        if let mockoonURL = request.mockoonRedirectedURL {
            let mockoonRows: [(key: String, value: String)] = [
                ("Status", "Active — request sent to Mockoon"),
                ("Original URL", request.url.absoluteString),
                ("Mockoon URL", mockoonURL.absoluteString),
            ]
            allSections.append(("🟢 Mockoon Redirect", mockoonRows))
        }

        sections = allSections
        tableView.reloadData()
    }
    
    private func showHeaders() {
        var requestRows = request.headers.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        if requestRows.isEmpty { requestRows = [("None", "")] }
        
        var allSections = [("Request Headers", requestRows)]
        
        if let response = request.response {
            var responseRows = response.headers.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
            if responseRows.isEmpty { responseRows = [("None", "")] }
            allSections.append(("Response Headers", responseRows))
        }
        
        sections = allSections
        tableView.reloadData()
    }
    
    private func showBody() {
        var text = "── REQUEST BODY ──\n\n"
        if let body = request.body {
            text += body.prettyJSON ?? "<Non-JSON Body>"
        } else {
            text += "<Empty>"
        }
        
        if let response = request.response {
            text += "\n\n── RESPONSE BODY ──\n\n"
            if let body = response.body {
                text += body.prettyJSON ?? "<Non-JSON Body>"
            } else {
                text += "<Empty>"
            }
        }
        codeView.text = text
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath) as! DetailCell
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.configure(key: row.key, value: row.value)
        return cell
    }
}

private final class DetailCell: UITableViewCell {
    private let keyLabel = UILabel()
    private let valueLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        
        keyLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        keyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)
        
        valueLabel.font = UIFont.phantomMonospaced(size: 11, weight: .medium)
        valueLabel.textColor = PhantomTheme.shared.textColor
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            keyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            
            valueLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: keyLabel.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }
    
    func configure(key: String, value: String) {
        keyLabel.text = key.uppercased()
        valueLabel.text = value
    }
}
#endif
