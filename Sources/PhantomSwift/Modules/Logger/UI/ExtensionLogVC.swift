#if DEBUG
import UIKit

/// Displays logs captured from App Extensions (Widgets, Push, etc.)
internal final class ExtensionLogVC: UIViewController {

    // MARK: - State

    private var allLogs:      [String] = []
    private var filteredLogs: [String] = []
    private var searchText:   String   = ""

    // MARK: - UI

    private let searchBar  = UISearchBar()
    private let tableView  = UITableView(frame: .zero, style: .plain)
    private let statsLabel = UILabel()
    private let emptyLabel = UILabel()

    private static let cellID = "ExtLogCell"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Extension Sidekick"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildUI()
        loadLogs()
    }

    // MARK: - UI Setup

    private func buildUI() {
        // Nav buttons
        let refreshBtn: UIBarButtonItem
        let exportBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            refreshBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(loadLogs))
            exportBtn  = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportLogs))
        } else {
            refreshBtn = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(loadLogs))
            exportBtn  = UIBarButtonItem(title: "Export",  style: .plain, target: self, action: #selector(exportLogs))
        }
        exportBtn.tintColor = PhantomTheme.shared.primaryColor
        navigationItem.rightBarButtonItems = [refreshBtn, exportBtn]

        // Search bar
        searchBar.placeholder = "Search extension logs…"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate  = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = PhantomTheme.shared.surfaceColor
            searchBar.searchTextField.textColor       = PhantomTheme.shared.textColor
        }
        view.addSubview(searchBar)

        // Stats
        statsLabel.font      = .systemFont(ofSize: 11, weight: .semibold)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsLabel)

        // Table
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.separatorStyle  = .none
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Empty label
        emptyLabel.text          = "No extension logs yet.\nConfigure an App Group and call PhantomExtensionBus.shared.postLog(…) from your extension."
        emptyLabel.font          = .systemFont(ofSize: 14)
        emptyLabel.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden      = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            statsLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 6),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Data

    @objc private func loadLogs() {
        allLogs = PhantomExtensionBus.shared.getLogs().reversed()
        applyFilter()
    }

    private func applyFilter() {
        if searchText.isEmpty {
            filteredLogs = allLogs
        } else {
            let q = searchText.lowercased()
            filteredLogs = allLogs.filter { $0.lowercased().contains(q) }
        }
        tableView.reloadData()
        let total   = allLogs.count
        let visible = filteredLogs.count
        statsLabel.text = searchText.isEmpty
            ? "\(total) log\(total == 1 ? "" : "s") from extensions"
            : "\(visible) of \(total) logs"
        emptyLabel.isHidden = !filteredLogs.isEmpty
    }

    // MARK: - Actions

    @objc private func exportLogs() {
        let text = filteredLogs.reversed().joined(separator: "\n")
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ExtensionLogVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredLogs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let raw  = filteredLogs[indexPath.row]
        cell.backgroundColor = .clear
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.backgroundView  = nil
        cell.selectedBackgroundView = {
            let v = UIView(); v.backgroundColor = UIColor.white.withAlphaComponent(0.05); return v
        }()

        // Parse timestamp / tag / message from stored string format: "[ts] [tag] msg"
        let accent = UIColor.Phantom.electricIndigo

        if #available(iOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = raw
            content.textProperties.font          = UIFont.phantomMonospaced(size: 11, weight: .regular)
            content.textProperties.color         = PhantomTheme.shared.textColor
            content.textProperties.numberOfLines = 0
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text          = raw
            cell.textLabel?.textColor     = PhantomTheme.shared.textColor
            cell.textLabel?.font          = UIFont.phantomMonospaced(size: 11, weight: .regular)
            cell.textLabel?.numberOfLines = 0
        }

        // Left accent bar
        if cell.viewWithTag(9901) == nil {
            let bar = UIView()
            bar.tag = 9901
            bar.backgroundColor    = accent.withAlphaComponent(0.5)
            bar.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                bar.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                bar.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                bar.widthAnchor.constraint(equalToConstant: 3),
            ])
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ExtensionLogVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = filteredLogs[indexPath.row]
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let copy = UIContextualAction(style: .normal, title: "Copy") { [weak self] _, _, done in
            UIPasteboard.general.string = self?.filteredLogs[indexPath.row]
            done(true)
        }
        copy.backgroundColor = UIColor.Phantom.electricIndigo
        return UISwipeActionsConfiguration(actions: [copy])
    }
}

// MARK: - UISearchBarDelegate

extension ExtensionLogVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
#endif
