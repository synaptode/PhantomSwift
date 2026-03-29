#if DEBUG
import UIKit

// MARK: - LayoutConflictVC

/// Lists Auto Layout constraint conflicts captured in real-time via the stderr tap.
internal final class LayoutConflictVC: UIViewController {

    private var entries: [LayoutConflictEntry] = []
    private var observerID: UUID?

    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        }
        return UITableView(frame: .zero, style: .grouped)
    }()

    private lazy var emptyView = PhantomEmptyStateView(
        emoji: "📐",
        title: "No Layout Conflicts",
        message: "AutoLayout constraint breaks will appear here in real-time as you use the app."
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Layout Conflicts"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupTableView()
        setupNav()
        reload()
        // Detector start is idempotent; safe to call here as well.
        PhantomLayoutConflictDetector.shared.start()
        observerID = PhantomLayoutConflictDetector.shared.addObserver { [weak self] in
            self?.reload()
        }
    }

    deinit {
        if let id = observerID { PhantomLayoutConflictDetector.shared.removeObserver(id) }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.backgroundColor   = .clear
        tableView.separatorStyle    = .none
        tableView.register(LayoutConflictCell.self, forCellReuseIdentifier: LayoutConflictCell.reuseID)
        tableView.dataSource        = self
        tableView.delegate          = self
        tableView.rowHeight         = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.contentInset      = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
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
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantOrange
    }

    // MARK: - Data

    private func reload() {
        entries = PhantomLayoutConflictDetector.shared.getAll()
        tableView.reloadData()
        emptyView.isHidden = !entries.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !entries.isEmpty
    }

    @objc private func clearAll() {
        PhantomLayoutConflictDetector.shared.clear()
        reload()
    }
}

// MARK: - UITableViewDataSource + Delegate

extension LayoutConflictVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !entries.isEmpty else { return nil }
        return "\(entries.count) conflict\(entries.count == 1 ? "" : "s") captured"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LayoutConflictCell.reuseID, for: indexPath
        ) as! LayoutConflictCell
        cell.configure(with: entries[indexPath.row], index: indexPath.row + 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = LayoutConflictDetailVC(entry: entries[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - LayoutConflictCell

private final class LayoutConflictCell: UITableViewCell {
    static let reuseID = "LayoutConflictCell"

    private let indexBadge    = UILabel()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let dateLabel     = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        accessoryType   = .disclosureIndicator

        indexBadge.font              = .systemFont(ofSize: 11, weight: .black)
        indexBadge.textColor         = .white
        indexBadge.backgroundColor   = UIColor.Phantom.vibrantOrange
        indexBadge.textAlignment     = .center
        indexBadge.layer.cornerRadius = 12
        indexBadge.clipsToBounds     = true

        titleLabel.font              = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor         = PhantomTheme.shared.textColor
        titleLabel.numberOfLines     = 2

        subtitleLabel.font           = .systemFont(ofSize: 12)
        subtitleLabel.textColor      = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        subtitleLabel.numberOfLines  = 1

        dateLabel.font               = .systemFont(ofSize: 11)
        dateLabel.textColor          = PhantomTheme.shared.textColor.withAlphaComponent(0.4)

        [indexBadge, titleLabel, subtitleLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            indexBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            indexBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexBadge.widthAnchor.constraint(equalToConstant: 28),
            indexBadge.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: indexBadge.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            dateLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 3),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with entry: LayoutConflictEntry, index: Int) {
        indexBadge.text    = "\(index)"
        titleLabel.text    = entry.viewClass.map { "View: \($0)" } ?? "Unknown View"
        let cnt            = entry.constraints.count
        subtitleLabel.text = "\(cnt) constraint\(cnt == 1 ? "" : "s") involved"

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .medium
        dateLabel.text = fmt.string(from: entry.date)
    }
}

// MARK: - LayoutConflictDetailVC

private final class LayoutConflictDetailVC: UIViewController {

    private let entry: LayoutConflictEntry
    private let textView = UITextView()

    init(entry: LayoutConflictEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Conflict Detail"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildTextView()
        buildCopyButton()
        renderContent()
    }

    private func buildTextView() {
        textView.isEditable         = false
        textView.backgroundColor    = PhantomTheme.shared.surfaceColor
        textView.textColor          = PhantomTheme.shared.textColor
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.layer.cornerRadius = 12
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

    private func buildCopyButton() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "doc.on.clipboard"),
                style: .plain, target: self, action: #selector(copyContent)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Copy", style: .plain, target: self, action: #selector(copyContent)
            )
        }
    }

    private func renderContent() {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .long

        var text = """
╔══════════════════════════════════════
║  PHANTOM — AUTO LAYOUT CONFLICT
╠══════════════════════════════════════
║  Date:  \(fmt.string(from: entry.date))
║  View:  \(entry.viewClass ?? "unknown")
║  Constraints: \(entry.constraints.count)
╠══════════════════════════════════════
║  FULL MESSAGE
╚══════════════════════════════════════
\(entry.message)

══════════════════════════════════════
STACK TRACE (detection point)
══════════════════════════════════════\n
"""
        text += entry.callStack.joined(separator: "\n")
        textView.text = text
    }

    @objc private func copyContent() {
        UIPasteboard.general.string = textView.text

        let toast = UILabel()
        toast.text            = " Copied! "
        toast.textAlignment   = .center
        toast.backgroundColor = UIColor.Phantom.vibrantGreen
        toast.textColor       = .white
        toast.font            = .systemFont(ofSize: 13, weight: .semibold)
        toast.layer.cornerRadius = 8
        toast.clipsToBounds   = true
        toast.alpha           = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 36),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        UIView.animate(withDuration: 0.2, animations: { toast.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.4, delay: 1.2, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
#endif
