#if DEBUG
import UIKit

// MARK: - CrashLogVC

/// Lists crash entries captured during the current and previous sessions.
internal final class CrashLogVC: UIViewController {

    private var entries: [CrashEntry] = []
    private var observerID: UUID?

    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        }
        return UITableView(frame: .zero, style: .grouped)
    }()

    private lazy var emptyView = PhantomEmptyStateView(
        emoji: "✅",
        title: "No Crashes Recorded",
        message: "Uncaught NSExceptions and MetricKit crash diagnostics appear here."
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Crash Logs"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupTableView()
        setupNav()
        reload()
        observerID = PhantomCrashLogStore.shared.addObserver { [weak self] in
            self?.reload()
        }
    }

    deinit {
        if let id = observerID { PhantomCrashLogStore.shared.removeObserver(id) }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle  = .none
        tableView.register(CrashLogCell.self, forCellReuseIdentifier: CrashLogCell.reuseID)
        tableView.dataSource                 = self
        tableView.delegate                   = self
        tableView.rowHeight                  = UITableView.automaticDimension
        tableView.estimatedRowHeight         = 90
        tableView.contentInset               = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func setupNav() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "trash"),
                style: .plain, target: self, action: #selector(clearAll)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Clear", style: .plain, target: self, action: #selector(clearAll)
            )
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantRed
    }

    // MARK: - Data

    private func reload() {
        entries = PhantomCrashLogStore.shared.getAll()
        tableView.reloadData()
        emptyView.isHidden = !entries.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !entries.isEmpty
    }

    @objc private func clearAll() {
        let alert = UIAlertController(
            title: "Clear All Crashes",
            message: "This removes all recorded crash entries from disk.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            PhantomCrashLogStore.shared.clear()
            self?.reload()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource + Delegate

extension CrashLogVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !entries.isEmpty else { return nil }
        return "\(entries.count) crash\(entries.count == 1 ? "" : "es") recorded"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CrashLogCell.reuseID, for: indexPath
        ) as! CrashLogCell
        cell.configure(with: entries[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = CrashLogDetailVC(entry: entries[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - CrashLogCell

private final class CrashLogCell: UITableViewCell {

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .medium
        return fmt
    }()
    static let reuseID = "CrashLogCell"

    private let typeBadge    = UILabel()
    private let reasonLabel  = UILabel()
    private let dateLabel    = UILabel()
    private let versionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        accessoryType   = .disclosureIndicator

        typeBadge.font            = .systemFont(ofSize: 10, weight: .bold)
        typeBadge.textColor       = .white
        typeBadge.layer.cornerRadius = 6
        typeBadge.clipsToBounds   = true
        typeBadge.textAlignment   = .center

        reasonLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        reasonLabel.textColor     = PhantomTheme.shared.textColor
        reasonLabel.numberOfLines = 2

        dateLabel.font            = .systemFont(ofSize: 11)
        dateLabel.textColor       = PhantomTheme.shared.textColor.withAlphaComponent(0.5)

        versionLabel.font         = .systemFont(ofSize: 11)
        versionLabel.textColor    = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        versionLabel.textAlignment = .right

        [typeBadge, reasonLabel, dateLabel, versionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            typeBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            typeBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeBadge.heightAnchor.constraint(equalToConstant: 20),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),

            reasonLabel.topAnchor.constraint(equalTo: typeBadge.bottomAnchor, constant: 6),
            reasonLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            reasonLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            versionLabel.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with entry: CrashEntry) {
        reasonLabel.text  = entry.reason
        versionLabel.text = "v\(entry.appVersion)"

        dateLabel.text = CrashLogCell.dateFormatter.string(from: entry.date)

        switch entry.type {
        case .exception:
            typeBadge.text            = "  EXCEPTION  "
            typeBadge.backgroundColor = UIColor.Phantom.vibrantRed
        case .metricKit:
            typeBadge.text            = "  METRICKIT  "
            typeBadge.backgroundColor = UIColor.Phantom.electricIndigo
        }
    }
}

// MARK: - CrashLogDetailVC

private final class CrashLogDetailVC: UIViewController {

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .long
        return fmt
    }()

    private let entry: CrashEntry
    private let textView = UITextView()

    init(entry: CrashEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entry.type.rawValue
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildTextView()
        buildShareButton()
        renderContent()
    }

    private func buildTextView() {
        textView.isEditable             = false
        textView.backgroundColor        = PhantomTheme.shared.surfaceColor
        textView.textColor              = PhantomTheme.shared.textColor
        textView.textContainerInset     = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.layer.cornerRadius     = 12
        if #available(iOS 13.0, *) {
            textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        } else {
            textView.font = UIFont(name: "Menlo-Regular", size: 11) ?? .systemFont(ofSize: 11)
        }
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func buildShareButton() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain, target: self, action: #selector(share)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Share", style: .plain, target: self, action: #selector(share)
            )
        }
    }

    private func renderContent() {
        var text = """
╔══════════════════════════════════════
║  PHANTOM — CRASH REPORT
╠══════════════════════════════════════
║  Type:    \(entry.type.rawValue)
║  Date:    \(CrashLogDetailVC.dateFormatter.string(from: entry.date))
║  App v:   \(entry.appVersion)
║  iOS:     \(entry.osVersion)
╠══════════════════════════════════════
║  REASON
╚══════════════════════════════════════
\(entry.reason)

══════════════════════════════════════
CALL STACK
══════════════════════════════════════\n
"""
        text += entry.callStack.joined(separator: "\n")
        textView.text = text
    }

    @objc private func share() {
        guard let text = textView.text, !text.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(vc, animated: true)
    }
}
#endif
