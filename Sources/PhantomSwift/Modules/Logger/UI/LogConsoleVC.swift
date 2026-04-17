#if DEBUG
import UIKit

// MARK: - LogConsoleVC

/// Full-featured live log console with level filtering, search, and per-entry detail.
internal final class LogConsoleVC: UIViewController, PhantomEventObserver {

    private static let exportFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return df
    }()

    // MARK: - State

    private var allLogs:      [LogEntry] = []
    private var filteredLogs: [LogEntry] = []
    private var searchText:   String     = ""
    private var activeLevels: Set<LogLevel> = []   // empty = show all

    // MARK: - UI

    private let searchBar   = UISearchBar()
    private let filterScroll = UIScrollView()
    private let filterStack  = UIStackView()
    private let tableView    = UITableView(frame: .zero, style: .plain)
    private let statsLabel   = UILabel()
    private let emptyLabel   = UILabel()

    private var levelChips: [LevelChip] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Console"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildUI()
        loadLogs()
        PhantomEventBus.shared.subscribe(self, to: "logAdded")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            PhantomEventBus.shared.unsubscribe(self, from: "logAdded")
        }
    }

    deinit {
        PhantomEventBus.shared.unsubscribe(self, from: "logAdded")
    }

    // MARK: - UI Setup

    private func buildUI() {
        setupNavBar()
        setupSearchBar()
        setupFilterRow()
        setupStats()
        setupTable()
        setupEmpty()
        layoutAll()
    }

    private func setupNavBar() {
        let clearBtn: UIBarButtonItem
        let exportBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            clearBtn  = UIBarButtonItem(image: UIImage(systemName: "trash"),        style: .plain, target: self, action: #selector(clearLogs))
            exportBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportLogs))
        } else {
            clearBtn  = UIBarButtonItem(title: "Clear",  style: .plain, target: self, action: #selector(clearLogs))
            exportBtn = UIBarButtonItem(title: "Export", style: .plain, target: self, action: #selector(exportLogs))
        }
        clearBtn.tintColor = UIColor.Phantom.error
        exportBtn.tintColor = PhantomTheme.shared.primaryColor
        navigationItem.rightBarButtonItems = [clearBtn, exportBtn]
    }

    private func setupSearchBar() {
        searchBar.placeholder = "Search message, tag, file…"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = PhantomTheme.shared.surfaceColor
            searchBar.searchTextField.textColor       = PhantomTheme.shared.textColor
        }
        view.addSubview(searchBar)
    }

    private func setupFilterRow() {
        filterScroll.showsHorizontalScrollIndicator = false
        filterScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterScroll)

        filterStack.axis    = .horizontal
        filterStack.spacing = 8
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterScroll.addSubview(filterStack)

        // "ALL" chip
        let allChip = LevelChip(title: "ALL", accent: PhantomTheme.shared.primaryColor)
        allChip.isActive = true
        allChip.addTarget(self, action: #selector(allChipTapped(_:)), for: .touchUpInside)
        filterStack.addArrangedSubview(allChip)
        levelChips.append(allChip)   // index 0 = ALL

        for level in LogLevel.allCases {
            let chip = LevelChip(title: "\(level.emoji) \(level.name)", accent: accentColor(for: level))
            chip.level = level
            chip.addTarget(self, action: #selector(levelChipTapped(_:)), for: .touchUpInside)
            filterStack.addArrangedSubview(chip)
            levelChips.append(chip)
        }

        NSLayoutConstraint.activate([
            filterStack.topAnchor.constraint(equalTo: filterScroll.topAnchor, constant: 6),
            filterStack.bottomAnchor.constraint(equalTo: filterScroll.bottomAnchor, constant: -6),
            filterStack.leadingAnchor.constraint(equalTo: filterScroll.leadingAnchor, constant: 14),
            filterStack.trailingAnchor.constraint(equalTo: filterScroll.trailingAnchor, constant: -14),
            filterStack.heightAnchor.constraint(equalTo: filterScroll.heightAnchor, constant: -12),
        ])
    }

    private func setupStats() {
        statsLabel.font      = .systemFont(ofSize: 11, weight: .semibold)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsLabel)
    }

    private func setupTable() {
        tableView.register(LogCell.self, forCellReuseIdentifier: LogCell.reuseID)
        tableView.separatorStyle  = .none
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = 64
        tableView.rowHeight          = UITableView.automaticDimension
        tableView.contentInset       = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    private func setupEmpty() {
        emptyLabel.text          = "No logs match your filters."
        emptyLabel.font          = .systemFont(ofSize: 15)
        emptyLabel.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden      = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
    }

    private func layoutAll() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            filterScroll.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            filterScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterScroll.heightAnchor.constraint(equalToConstant: 44),

            statsLabel.topAnchor.constraint(equalTo: filterScroll.bottomAnchor, constant: 6),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Data

    private func loadLogs() {
        allLogs = LogStore.shared.getAll()
        applyFilter()
    }

    private func applyFilter() {
        filteredLogs = allLogs.filter { log in
            let levelOK = activeLevels.isEmpty || activeLevels.contains(log.level)
            guard levelOK else { return false }
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return log.message.lowercased().contains(q)
                || (log.tag?.lowercased().contains(q) ?? false)
                || URL(fileURLWithPath: log.file).lastPathComponent.lowercased().contains(q)
        }
        tableView.reloadData()
        updateStats()
        emptyLabel.isHidden = !filteredLogs.isEmpty
        if !filteredLogs.isEmpty { scrollToBottomIfNeeded(animated: false) }
    }

    private func appendLog(_ log: LogEntry) {
        allLogs.append(log)
        let levelOK = activeLevels.isEmpty || activeLevels.contains(log.level)
        let q       = searchText.lowercased()
        let textOK  = searchText.isEmpty
            || log.message.lowercased().contains(q)
            || (log.tag?.lowercased().contains(q) ?? false)
        guard levelOK && textOK else {
            updateStats()
            return
        }
        filteredLogs.append(log)
        tableView.insertRows(at: [IndexPath(row: filteredLogs.count - 1, section: 0)], with: .automatic)
        updateStats()
        emptyLabel.isHidden = true
        scrollToBottomIfNeeded(animated: true)
    }

    private func updateStats() {
        let total   = allLogs.count
        let visible = filteredLogs.count
        if activeLevels.isEmpty && searchText.isEmpty {
            statsLabel.text = "\(total) log\(total == 1 ? "" : "s") captured"
        } else {
            statsLabel.text = "\(visible) of \(total) logs"
        }
    }

    private func scrollToBottomIfNeeded(animated: Bool) {
        guard !filteredLogs.isEmpty else { return }
        let lastRow       = filteredLogs.count - 1
        let contentHeight = tableView.contentSize.height
        let visibleHeight = tableView.bounds.height - tableView.adjustedContentInset.bottom
        let nearBottom    = contentHeight <= visibleHeight
            || tableView.contentOffset.y >= contentHeight - visibleHeight - 100
        guard nearBottom || !animated else { return }
        DispatchQueue.main.async { [weak self] in
            self?.tableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: animated)
        }
    }

    // MARK: - Actions

    @objc private func allChipTapped(_ sender: LevelChip) {
        activeLevels.removeAll()
        levelChips.forEach { $0.isActive = false }
        levelChips.first?.isActive = true   // ALL chip stays active
        applyFilter()
    }

    @objc private func levelChipTapped(_ sender: LevelChip) {
        guard let level = sender.level else { return }
        if activeLevels.contains(level) {
            activeLevels.remove(level)
            sender.isActive = false
        } else {
            activeLevels.insert(level)
            sender.isActive = true
        }
        // If nothing selected, revert to ALL
        let allChip = levelChips.first
        if activeLevels.isEmpty {
            allChip?.isActive = true
        } else {
            allChip?.isActive = false
        }
        applyFilter()
    }

    @objc private func clearLogs() {
        let alert = UIAlertController(title: "Clear All Logs?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            LogStore.shared.clear()
            self?.loadLogs()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func exportLogs() {
        let text = filteredLogs.map { log in
            let ts   = LogConsoleVC.exportFormatter.string(from: log.timestamp)
            let file = URL(fileURLWithPath: log.file).lastPathComponent
            let tag  = log.tag ?? "-"
            return "[\(ts)] [\(log.level.name)] [\(tag)] [\(file):\(log.line)] \(log.message)"
        }.joined(separator: "\n")
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }

    // MARK: - PhantomEventObserver

    func onEvent(_ event: PhantomEvent) {
        if case .logAdded(let log) = event {
            DispatchQueue.main.async { [weak self] in self?.appendLog(log) }
        }
    }

    // MARK: - Helpers

    private func accentColor(for level: LogLevel) -> UIColor {
        switch level {
        case .verbose:  return PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        case .debug:    return UIColor.Phantom.neonAzure
        case .info:     return UIColor.Phantom.vibrantGreen
        case .warning:  return UIColor.Phantom.vibrantOrange
        case .error:    return UIColor.Phantom.error
        case .critical: return UIColor.Phantom.vibrantRed
        }
    }
}

// MARK: - UITableViewDataSource

extension LogConsoleVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredLogs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LogCell.reuseID, for: indexPath) as! LogCell
        cell.configure(with: filteredLogs[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LogConsoleVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detail = LogDetailVC(entry: filteredLogs[indexPath.row])
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let copy = UIContextualAction(style: .normal, title: "Copy") { [weak self] _, _, done in
            UIPasteboard.general.string = self?.filteredLogs[indexPath.row].message
            done(true)
        }
        copy.backgroundColor = UIColor.Phantom.neonAzure
        return UISwipeActionsConfiguration(actions: [copy])
    }
}

// MARK: - UISearchBarDelegate

extension LogConsoleVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - LevelChip

private final class LevelChip: UIControl {
    var level: LogLevel?
    private let label = UILabel()
    private let accent: UIColor

    var isActive: Bool = false { didSet { updateAppearance() } }

    init(title: String, accent: UIColor) {
        self.accent = accent
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        layer.cornerRadius = 12
        layer.borderWidth  = 1
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
            backgroundColor     = accent.withAlphaComponent(0.2)
            layer.borderColor   = accent.cgColor
            label.textColor     = accent
        } else {
            backgroundColor     = PhantomTheme.shared.surfaceColor
            layer.borderColor   = UIColor.white.withAlphaComponent(0.1).cgColor
            label.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        }
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1.0 } }
}

// MARK: - LogCell

private final class LogCell: UITableViewCell {
    static let reuseID = "LogCell"

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()

    private let accentBar    = UIView()
    private let levelBadge   = UILabel()
    private let messageLabel = UILabel()
    private let metaLabel    = UILabel()
    private let tagBadge     = UIView()
    private let tagLabel     = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .default
        selectedBackgroundView = {
            let v = UIView()
            v.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            return v
        }()

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.layer.cornerRadius = 2
        contentView.addSubview(accentBar)

        levelBadge.font      = .systemFont(ofSize: 16)
        levelBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(levelBadge)

        messageLabel.font          = UIFont.phantomMonospaced(size: 12, weight: .medium)
        messageLabel.textColor     = PhantomTheme.shared.textColor
        messageLabel.numberOfLines = 4
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)

        tagBadge.layer.cornerRadius = 4
        tagBadge.layer.masksToBounds = true
        tagBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagBadge)

        tagLabel.font      = .systemFont(ofSize: 9.5, weight: .bold)
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        tagBadge.addSubview(tagLabel)

        metaLabel.font      = .systemFont(ofSize: 10)
        metaLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        sep.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sep)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            accentBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            levelBadge.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            levelBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            levelBadge.widthAnchor.constraint(equalToConstant: 22),

            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: levelBadge.trailingAnchor, constant: 6),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            tagBadge.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 5),
            tagBadge.leadingAnchor.constraint(equalTo: levelBadge.trailingAnchor, constant: 6),

            tagLabel.topAnchor.constraint(equalTo: tagBadge.topAnchor, constant: 2),
            tagLabel.bottomAnchor.constraint(equalTo: tagBadge.bottomAnchor, constant: -2),
            tagLabel.leadingAnchor.constraint(equalTo: tagBadge.leadingAnchor, constant: 5),
            tagLabel.trailingAnchor.constraint(equalTo: tagBadge.trailingAnchor, constant: -5),

            metaLabel.centerYAnchor.constraint(equalTo: tagBadge.centerYAnchor),
            metaLabel.leadingAnchor.constraint(equalTo: tagBadge.trailingAnchor, constant: 8),
            metaLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            sep.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor),
            sep.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    func configure(with entry: LogEntry) {
        let accent = accentColor(for: entry.level)
        accentBar.backgroundColor  = accent
        levelBadge.text            = entry.level.emoji

        messageLabel.text          = entry.message
        messageLabel.textColor     = accent.withAlphaComponent(entry.level == .verbose ? 0.6 : 1.0)

        let tag = entry.tag ?? "untagged"
        tagLabel.text              = tag.uppercased()
        tagLabel.textColor         = accent
        tagBadge.backgroundColor   = accent.withAlphaComponent(0.12)

        let file = URL(fileURLWithPath: entry.file).lastPathComponent
        metaLabel.text = "\(file):\(entry.line) · \(LogCell.dateFormatter.string(from: entry.timestamp))"
    }

    private func accentColor(for level: LogLevel) -> UIColor {
        switch level {
        case .verbose:  return PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        case .debug:    return UIColor.Phantom.neonAzure
        case .info:     return UIColor.Phantom.vibrantGreen
        case .warning:  return UIColor.Phantom.vibrantOrange
        case .error:    return UIColor.Phantom.error
        case .critical: return UIColor.Phantom.vibrantRed
        }
    }
}

// MARK: - LogDetailVC

private final class LogDetailVC: UIViewController {

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    private let entry: LogEntry
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        } else {
            return UITableView(frame: .zero, style: .grouped)
        }
    }()

    private static let cellID = "DetailCell"

    init(entry: LogEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log Detail"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        if #available(iOS 13.0, *) {
            let copyBtn = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(copyMessage))
            navigationItem.rightBarButtonItem = copyBtn
        } else {
            let copyBtn = UIBarButtonItem(title: "Copy", style: .plain, target: self, action: #selector(copyMessage))
            navigationItem.rightBarButtonItem = copyBtn
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Copy", style: .plain, target: self, action: #selector(copyMessage))
        }

        tableView.backgroundColor = .clear
        tableView.dataSource      = self
        tableView.delegate        = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func copyMessage() {
        UIPasteboard.general.string = entry.message
    }

    private var sections: [(header: String, rows: [(label: String, value: String)])] {
        let file = URL(fileURLWithPath: entry.file).lastPathComponent
        return [
            ("ENTRY", [
                ("Level",    "\(entry.level.emoji) \(entry.level.name)"),
                ("Tag",      entry.tag ?? "—"),
                ("Time",     LogDetailVC.dateFormatter.string(from: entry.timestamp)),
            ]),
            ("LOCATION", [
                ("File",     file),
                ("Function", entry.function),
                ("Line",     "\(entry.line)"),
            ]),
            ("MESSAGE", [
                ("Full Message", entry.message),
            ]),
        ]
    }
}

extension LogDetailVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let row  = sections[indexPath.section].rows[indexPath.row]
        cell.backgroundColor = PhantomTheme.shared.surfaceColor

        if #available(iOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = row.label
            content.textProperties.font  = .systemFont(ofSize: 12, weight: .semibold)
            content.textProperties.color = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
            content.secondaryText = row.value
            content.secondaryTextProperties.font         = UIFont.phantomMonospaced(size: 13, weight: .regular)
            content.secondaryTextProperties.color        = PhantomTheme.shared.textColor
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text  = row.label
            cell.textLabel?.font  = .systemFont(ofSize: 12, weight: .semibold)
            cell.textLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
            cell.detailTextLabel?.text  = row.value
            cell.detailTextLabel?.font  = UIFont.phantomMonospaced(size: 13, weight: .regular)
            cell.detailTextLabel?.textColor = PhantomTheme.shared.textColor
            cell.detailTextLabel?.numberOfLines = 0
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        UIPasteboard.general.string = row.value
    }
}
#endif
