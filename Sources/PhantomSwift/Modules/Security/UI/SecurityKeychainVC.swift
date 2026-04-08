#if DEBUG
import UIKit
import Security

// MARK: - KeychainInspectorVC

/// Enumerates all accessible keychain items in the app's keychain groups.
/// Values (secrets) are NEVER displayed — only metadata is shown.
internal final class SecurityKeychainVC: UIViewController {

    // MARK: - Model

    struct KeychainItem {
        let service:     String
        let account:     String
        let accessGroup: String?
        let accessible:  String
        let createdAt:   Date?
        let modifiedAt:  Date?
    }

    // MARK: - State

    private var allItems:      [KeychainItem] = []
    private var filteredItems: [KeychainItem] = []
    private var searchText:    String = ""
    private var isLoading = false

    // MARK: - UI

    private let tableView   = UITableView(frame: .zero, style: .plain)
    private let searchBar   = UISearchBar()
    private let emptyLabel  = UILabel()
    private let spinner     = UIActivityIndicatorView()
    private let statsLabel  = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keychain Inspector"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildUI()
        loadItems()
    }

    // MARK: - UI Setup

    private func buildUI() {
        // Stats label (header)
        statsLabel.font      = .systemFont(ofSize: 11, weight: .medium)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        statsLabel.textAlignment = .center
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        // Search bar
        searchBar.barStyle    = PhantomTheme.shared.currentTheme == .light ? .default : .black
        searchBar.placeholder = "Search service, account…"
        searchBar.delegate    = self
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        // Table
        tableView.backgroundColor  = .clear
        tableView.dataSource       = self
        tableView.delegate         = self
        tableView.register(KeychainItemCell.self, forCellReuseIdentifier: KeychainItemCell.reuseID)
        tableView.rowHeight             = UITableView.automaticDimension
        tableView.estimatedRowHeight    = 80
        tableView.tableFooterView       = UIView()
        tableView.separatorColor        = PhantomTheme.shared.textColor.withAlphaComponent(0.08)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        // Spinner
        if #available(iOS 13.0, *) { spinner.style = .medium } else { spinner.style = .gray }
        spinner.color = UIColor.Phantom.neonAzure
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        // Empty label
        emptyLabel.text          = "No keychain items found"
        emptyLabel.font          = .systemFont(ofSize: 15)
        emptyLabel.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden      = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        // Nav buttons
        if #available(iOS 13.0, *) {
            let refreshBtn = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise"), style: .plain,
                target: self, action: #selector(refresh))
            let exportBtn = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"), style: .plain,
                target: self, action: #selector(exportItems))
            refreshBtn.tintColor = UIColor.Phantom.neonAzure
            exportBtn.tintColor  = UIColor.Phantom.vibrantGreen
            navigationItem.rightBarButtonItems = [refreshBtn, exportBtn]
        } else {
            let refreshBtn = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refresh)
)
            let exportBtn = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"), style: .plain,
                target: self, action: #selector(exportItems))
            refreshBtn.tintColor = UIColor.Phantom.neonAzure
            exportBtn.tintColor  = UIColor.Phantom.vibrantGreen
            navigationItem.rightBarButtonItems = [refreshBtn, exportBtn]
        }

        [statsLabel, searchBar, tableView, spinner, emptyLabel].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            searchBar.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Load

    private func loadItems() {
        guard !isLoading else { return }
        isLoading = true
        spinner.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = Self.fetchKeychainItems()
            DispatchQueue.main.async {
                guard let self else { return }
                self.allItems = items
                self.applyFilter()
                self.isLoading = false
                self.spinner.stopAnimating()
                self.statsLabel.text = "\(items.count) item\(items.count == 1 ? "" : "s") in keychain  •  values hidden for security"
                self.emptyLabel.isHidden = !items.isEmpty
            }
        }
    }

    @objc private func refresh() { allItems = []; loadItems() }

    private func applyFilter() {
        let q = searchText.lowercased()
        filteredItems = q.isEmpty ? allItems : allItems.filter {
            $0.service.lowercased().contains(q) ||
            $0.account.lowercased().contains(q) ||
            ($0.accessGroup?.lowercased().contains(q) ?? false)
        }
        tableView.reloadData()
    }

    @objc private func exportItems() {
        let formatter = ISO8601DateFormatter()
        let arr: [[String: String]] = filteredItems.map { item in
            var d: [String: String] = [
                "service": item.service,
                "account": item.account,
                "accessible": item.accessible,
            ]
            if let ag = item.accessGroup { d["accessGroup"] = ag }
            if let c  = item.createdAt   { d["createdAt"]   = formatter.string(from: c) }
            return d
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return }
        let vc = UIActivityViewController(activityItems: ["// Keychain Metadata (no secrets)\n" + str], applicationActivities: nil)
        present(vc, animated: true)
    }

    // MARK: - Keychain Fetch

    private static func fetchKeychainItems() -> [KeychainItem] {
        var items: [KeychainItem] = []

        // Query for generic passwords
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecMatchLimit:       kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData:       false,  // Never fetch secret data
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let arr = result as? [[CFString: Any]] else {
            return items
        }

        for attrs in arr {
            let service     = attrs[kSecAttrService] as? String ?? "—"
            let account     = attrs[kSecAttrAccount] as? String ?? "—"
            let accessGroup = attrs[kSecAttrAccessGroup] as? String
            let accessible  = accessibleString(attrs[kSecAttrAccessible] as? String)
            let created     = attrs[kSecAttrCreationDate] as? Date
            let modified    = attrs[kSecAttrModificationDate] as? Date

            items.append(KeychainItem(
                service: service,
                account: account,
                accessGroup: accessGroup,
                accessible: accessible,
                createdAt: created,
                modifiedAt: modified
            ))
        }

        return items.sorted { $0.service < $1.service }
    }

    private static func accessibleString(_ raw: String?) -> String {
        guard let raw = raw else { return "Unknown" }
        let map: [(CFString, String)] = [
            (kSecAttrAccessibleWhenUnlocked,                    "WhenUnlocked"),
            (kSecAttrAccessibleAfterFirstUnlock,                "AfterFirstUnlock"),
            (kSecAttrAccessibleAlways,                          "Always"),
            (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,   "WhenPasscodeSet"),
            (kSecAttrAccessibleWhenUnlockedThisDeviceOnly,      "WhenUnlocked (ThisDevice)"),
            (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,  "AfterFirstUnlock (ThisDevice)"),
        ]
        return map.first { (raw as CFString) == $0.0 }?.1 ?? raw
    }

    // MARK: - Delete

    private func deleteItem(_ item: KeychainItem) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: item.service,
            kSecAttrAccount: item.account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            allItems.removeAll { $0.service == item.service && $0.account == item.account }
            applyFilter()
            statsLabel.text = "\(allItems.count) item\(allItems.count == 1 ? "" : "s") in keychain  •  values hidden for security"
        }
    }
}

// MARK: - UITableViewDataSource + Delegate

extension SecurityKeychainVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        filteredItems.isEmpty ? nil : "KEYCHAIN ITEMS  (metadata only)"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let h = view as? UITableViewHeaderFooterView else { return }
        h.textLabel?.font      = .systemFont(ofSize: 9.5, weight: .black)
        h.textLabel?.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.7)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: KeychainItemCell.reuseID, for: indexPath) as! KeychainItemCell
        cell.configure(with: filteredItems[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        UIPasteboard.general.string = "\(item.service) / \(item.account)"
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let item = filteredItems[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            let alert = UIAlertController(
                title: "Delete Keychain Item?",
                message: "'\(item.account)' from '\(item.service)' will be permanently removed.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self?.deleteItem(item)
                done(true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done(false) })
            self?.present(alert, animated: true)
        }
        return UISwipeActionsConfiguration(actions: [del])
    }
}

// MARK: - UISearchBarDelegate

extension SecurityKeychainVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

// MARK: - KeychainItemCell

private final class KeychainItemCell: UITableViewCell {
    static let reuseID = "KeychainItemCell"

    private let lockIcon     = UILabel()
    private let serviceLabel = UILabel()
    private let accountLabel = UILabel()
    private let groupLabel   = UILabel()
    private let accessLabel  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .default

        lockIcon.text      = "🔑"
        lockIcon.font      = .systemFont(ofSize: 22)
        lockIcon.translatesAutoresizingMaskIntoConstraints = false

        serviceLabel.font      = .systemFont(ofSize: 13, weight: .bold)
        serviceLabel.textColor = PhantomTheme.shared.textColor
        serviceLabel.numberOfLines = 1
        serviceLabel.translatesAutoresizingMaskIntoConstraints = false

        accountLabel.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        accountLabel.textColor = UIColor.Phantom.neonAzure
        accountLabel.translatesAutoresizingMaskIntoConstraints = false

        groupLabel.font      = .systemFont(ofSize: 10)
        groupLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        groupLabel.numberOfLines = 1
        groupLabel.translatesAutoresizingMaskIntoConstraints = false

        accessLabel.font      = .systemFont(ofSize: 10, weight: .semibold)
        accessLabel.textColor = UIColor.Phantom.vibrantGreen
        accessLabel.translatesAutoresizingMaskIntoConstraints = false

        [lockIcon, serviceLabel, accountLabel, groupLabel, accessLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            lockIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            lockIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            lockIcon.widthAnchor.constraint(equalToConstant: 28),

            serviceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            serviceLabel.leadingAnchor.constraint(equalTo: lockIcon.trailingAnchor, constant: 10),
            serviceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            accountLabel.topAnchor.constraint(equalTo: serviceLabel.bottomAnchor, constant: 3),
            accountLabel.leadingAnchor.constraint(equalTo: lockIcon.trailingAnchor, constant: 10),

            accessLabel.centerYAnchor.constraint(equalTo: accountLabel.centerYAnchor),
            accessLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            groupLabel.topAnchor.constraint(equalTo: accountLabel.bottomAnchor, constant: 3),
            groupLabel.leadingAnchor.constraint(equalTo: lockIcon.trailingAnchor, constant: 10),
            groupLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            groupLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with item: SecurityKeychainVC.KeychainItem) {
        serviceLabel.text = item.service
        accountLabel.text = item.account
        accessLabel.text  = item.accessible
        if let ag = item.accessGroup, !ag.isEmpty {
            groupLabel.text = "Group: \(ag)"
        } else {
            groupLabel.text = ""
        }
    }
}
#endif
