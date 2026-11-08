#if DEBUG
import UIKit
#if canImport(WebKit)
import WebKit

/// Inspector for WKWebView persistent storage: Cookies, LocalStorage, IndexedDB, and Cache records.
internal final class WebViewStorageVC: UIViewController {

    private let segmentControl = UISegmentedControl(items: ["Cookies", "Website Data"])
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    private var allCookies: [HTTPCookie] = []
    private var filteredCookies: [HTTPCookie] = []

    private var allRecords: [WKWebsiteDataRecord] = []
    private var filteredRecords: [WKWebsiteDataRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Storage"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigationItems()
        setupUI()
        setupTableView()
        reloadData()
    }

    private func setupNavigationItems() {
        let clearButton = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(didTapClearAll)
        )
        let refreshButton = UIBarButtonItem(
            image: UIImage.phantomSymbol("arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(didTapRefresh)
        )
        navigationItem.rightBarButtonItems = [clearButton, refreshButton]
    }

    private func setupUI() {
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentControl)

        searchBar.placeholder = "Search domain or name"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        tableView.backgroundColor = .clear
        tableView.separatorColor = PhantomTheme.shared.niagaraSeparator
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyLabel.text = "No storage records found"
        emptyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        emptyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            searchBar.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StorageRecordCell.self, forCellReuseIdentifier: "StorageRecordCell")
        tableView.rowHeight = 68
    }

    @objc private func didChangeSegment() {
        applyFilter()
    }

    @objc private func didTapRefresh() {
        reloadData()
    }

    @objc private func didTapClearAll() {
        let isCookieMode = segmentControl.selectedSegmentIndex == 0
        let message = isCookieMode
            ? "All cookies will be removed from WKHTTPCookieStore."
            : "LocalStorage, IndexedDB, and cache will be deleted."
        let alert = UIAlertController(
            title: isCookieMode ? "Clear All Cookies?" : "Clear All Website Data?",
            message: message,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            if isCookieMode {
                PhantomWebViewStorageManager.shared.clearAllCookies {
                    self?.reloadData()
                }
            } else {
                PhantomWebViewStorageManager.shared.clearAllWebsiteData {
                    self?.reloadData()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func reloadData() {
        PhantomWebViewStorageManager.shared.fetchCookies { [weak self] cookies in
            guard let self else { return }
            self.allCookies = cookies
            if self.segmentControl.selectedSegmentIndex == 0 {
                self.applyFilter()
            }
        }
        PhantomWebViewStorageManager.shared.fetchWebsiteDataRecords { [weak self] records in
            guard let self else { return }
            self.allRecords = records
            if self.segmentControl.selectedSegmentIndex == 1 {
                self.applyFilter()
            }
        }
    }

    private func applyFilter() {
        let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if segmentControl.selectedSegmentIndex == 0 {
            filteredCookies = allCookies.filter { cookie in
                guard !query.isEmpty else { return true }
                return cookie.name.lowercased().contains(query) || cookie.domain.lowercased().contains(query)
            }
            emptyLabel.isHidden = !filteredCookies.isEmpty
        } else {
            filteredRecords = allRecords.filter { record in
                guard !query.isEmpty else { return true }
                return record.displayName.lowercased().contains(query)
            }
            emptyLabel.isHidden = !filteredRecords.isEmpty
        }
        tableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate

extension WebViewStorageVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension WebViewStorageVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        segmentControl.selectedSegmentIndex == 0 ? filteredCookies.count : filteredRecords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "StorageRecordCell",
            for: indexPath
        ) as? StorageRecordCell else {
            return UITableViewCell()
        }

        if segmentControl.selectedSegmentIndex == 0 {
            let cookie = filteredCookies[indexPath.row]
            cell.configure(
                iconName: "lock.fill",
                title: cookie.name,
                subtitle: "\(cookie.domain)\(cookie.path)",
                badge: cookie.value
            )
        } else {
            let record = filteredRecords[indexPath.row]
            let typesList = record.dataTypes.joined(separator: ", ")
            cell.configure(
                iconName: "tray.full",
                title: record.displayName,
                subtitle: typesList,
                badge: nil
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }

        if segmentControl.selectedSegmentIndex == 0 {
            let cookie = filteredCookies[indexPath.row]
            PhantomWebViewStorageManager.shared.deleteCookie(cookie) { [weak self] in
                self?.reloadData()
            }
        } else {
            let record = filteredRecords[indexPath.row]
            PhantomWebViewStorageManager.shared.removeWebsiteDataRecord(record) { [weak self] in
                self?.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if segmentControl.selectedSegmentIndex == 0 {
            let cookie = filteredCookies[indexPath.row]
            let expiry = cookie.expiresDate?.description ?? "Session"
            let detail = [
                "Name: \(cookie.name)",
                "Domain: \(cookie.domain)",
                "Path: \(cookie.path)",
                "Expires: \(expiry)",
                "Secure: \(cookie.isSecure)",
                "HTTPOnly: \(cookie.isHTTPOnly)",
                "",
                "Value:",
                cookie.value
            ].joined(separator: "\n")
            let alert = UIAlertController(title: cookie.name, message: detail, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy Value", style: .default) { _ in
                UIPasteboard.general.string = cookie.value
            })
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
            present(alert, animated: true)
        }
    }
}

// MARK: - StorageRecordCell

private final class StorageRecordCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = PhantomTheme.shared.primaryColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        badgeLabel.font = UIFont.phantomMonospaced(size: 10, weight: .regular)
        badgeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        badgeLabel.textAlignment = .right
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -8),

            badgeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])
    }

    func configure(iconName: String, title: String, subtitle: String, badge: String?) {
        iconView.image = UIImage.phantomSymbol(iconName)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        badgeLabel.text = badge
        badgeLabel.isHidden = (badge == nil)
    }
}
#endif
#endif
