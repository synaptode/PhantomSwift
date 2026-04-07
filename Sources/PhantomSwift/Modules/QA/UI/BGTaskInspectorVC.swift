#if DEBUG
import UIKit
import BackgroundTasks

// MARK: - BGTaskInspectorVC

@available(iOS 13.0, *)
internal final class BGTaskInspectorVC: UITableViewController {

    // MARK: - State

    private var records: [BGTaskRecord] = []
    private var observerID: UUID?
    private var lastRefreshed: Date?

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case summary = 0
        case tasks = 1
    }

    // MARK: - Init

    internal init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Background Tasks"
        applyDarkAppearance()
        setupNavBar()
        setupTableView()

        observerID = PhantomBGTaskInspector.shared.addObserver { [weak self] updated in
            self?.records = updated
            self?.lastRefreshed = Date()
            self?.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phantom_applyNavBarAppearance(tintColor: UIColor.Phantom.vibrantOrange)
        records = PhantomBGTaskInspector.shared.records
        tableView.reloadData()
        PhantomBGTaskInspector.shared.startAutoRefresh(interval: 4)
        PhantomBGTaskInspector.shared.refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PhantomBGTaskInspector.shared.stopAutoRefresh()
    }

    deinit {
        if let id = observerID { PhantomBGTaskInspector.shared.removeObserver(id) }
    }

    // MARK: - Setup

    private func applyDarkAppearance() {
        tableView.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset  = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
    }

    private func setupNavBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain, target: self, action: #selector(refreshTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = UIColor.white.withAlphaComponent(0.55)
    }

    private func setupTableView() {
        tableView.register(BGTaskCell.self, forCellReuseIdentifier: BGTaskCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SummaryCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func refreshTapped() {
        PhantomBGTaskInspector.shared.refresh()
        let btn = navigationItem.rightBarButtonItem
        btn?.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { btn?.isEnabled = true }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .summary: return 1
        case .tasks:   return max(records.count, 1)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let wrapper = UIView()
        wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
        let label = UILabel()
        switch Section(rawValue: section)! {
        case .summary: label.text = "SCHEDULER STATUS"
        case .tasks:   label.text = records.isEmpty ? "NO PERMITTED TASKS" : "REGISTERED TASKS (\(records.count))"
        }
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
        ])
        return wrapper
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .tasks {
            let wrapper = UIView()
            wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
            let label = UILabel()
            if records.isEmpty {
                label.text = "Add BGTaskSchedulerPermittedIdentifiers to Info.plist to register tasks."
            } else if let date = lastRefreshed {
                let df = DateFormatter()
                df.dateFormat = "HH:mm:ss"
                label.text = "Last refreshed: \(df.string(from: date))  ·  Auto-refreshes every 4s"
            }
            label.font          = .systemFont(ofSize: 11)
            label.textColor     = UIColor.white.withAlphaComponent(0.25)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            ])
            return wrapper
        }
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.backgroundColor
        return v
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .tasks ? UITableView.automaticDimension : 8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {

        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SummaryCell", for: indexPath)
            cell.selectionStyle  = .none
            cell.backgroundColor = PhantomTheme.shared.surfaceColor

            let permitted = PhantomBGTaskInspector.shared.permittedCount
            let pending   = PhantomBGTaskInspector.shared.pendingCount
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)

            let pendingStr = pending > 0 ? "\(pending) pending" : "none pending"
            cell.textLabel?.text = "Permitted: \(permitted)  ·  Submitted: \(pendingStr)"
            cell.textLabel?.textColor = pending > 0
                ? UIColor.Phantom.vibrantOrange
                : UIColor.white.withAlphaComponent(0.4)

            let cancelBtn = UIButton(type: .system)
            cancelBtn.setTitle("Cancel All", for: .normal)
            cancelBtn.setTitleColor(UIColor.Phantom.vibrantRed, for: .normal)
            cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            cancelBtn.addTarget(self, action: #selector(cancelAllTapped), for: .touchUpInside)
            cell.accessoryView = pending > 0 ? cancelBtn : nil
            return cell

        case .tasks:
            if records.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SummaryCell", for: indexPath)
                cell.selectionStyle  = .none
                cell.backgroundColor = PhantomTheme.shared.surfaceColor
                cell.textLabel?.text      = "No identifiers declared in Info.plist"
                cell.textLabel?.textColor = UIColor.white.withAlphaComponent(0.25)
                cell.textLabel?.font      = UIFont.systemFont(ofSize: 14)
                cell.accessoryView = nil
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: BGTaskCell.reuseID, for: indexPath) as! BGTaskCell
            cell.configure(with: records[indexPath.row])
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .tasks, !records.isEmpty else { return }
        let detail = BGTaskDetailVC(record: records[indexPath.row])
        navigationController?.pushViewController(detail, animated: true)
    }

    @objc private func cancelAllTapped() {
        PhantomBGTaskInspector.shared.cancelAllPending { [weak self] in
            self?.tableView.reloadData()
        }
    }
}

// MARK: - BGTaskCell

@available(iOS 13.0, *)
private final class BGTaskCell: UITableViewCell {

    static let reuseID = "BGTaskCell"

    private let accentStrip  = UIView()
    private let iconBg       = UIView()
    private let iconView     = UIImageView()
    private let idLabel      = UILabel()
    private let typeLabel    = UILabel()
    private let statusPill   = UILabel()
    private let dateLabel    = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle  = .default

        let highlight = UIView()
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        selectedBackgroundView = highlight

        // ── Accent strip ─────────────────────────────────────────────────
        accentStrip.backgroundColor    = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
        accentStrip.layer.cornerRadius = 2
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentStrip)

        // ── Icon pill ─────────────────────────────────────────────────────
        iconBg.backgroundColor    = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 10
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBg)

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image       = UIImage(systemName: "clock.arrow.2.circlepath", withConfiguration: cfg)
        iconView.tintColor   = UIColor.Phantom.vibrantOrange
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // ── ID label ─────────────────────────────────────────────────────
        idLabel.font          = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        idLabel.textColor     = UIColor.white.withAlphaComponent(0.9)
        idLabel.numberOfLines = 2
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(idLabel)

        // ── Type label ────────────────────────────────────────────────────
        typeLabel.font      = UIFont.systemFont(ofSize: 11, weight: .medium)
        typeLabel.textColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.7)
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)

        // ── Status pill ───────────────────────────────────────────────────
        statusPill.font               = UIFont.systemFont(ofSize: 10, weight: .bold)
        statusPill.textColor          = .white
        statusPill.textAlignment      = .center
        statusPill.layer.cornerRadius = 8
        statusPill.clipsToBounds      = true
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusPill)

        // ── Date label ────────────────────────────────────────────────────
        dateLabel.font      = UIFont.systemFont(ofSize: 11)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            accentStrip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentStrip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            accentStrip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            accentStrip.widthAnchor.constraint(equalToConstant: 3),

            iconBg.leadingAnchor.constraint(equalTo: accentStrip.trailingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 36),
            iconBg.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            statusPill.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusPill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            statusPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            statusPill.heightAnchor.constraint(equalToConstant: 20),

            idLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            idLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            idLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusPill.leadingAnchor, constant: -8),

            typeLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 3),
            typeLabel.leadingAnchor.constraint(equalTo: idLabel.leadingAnchor),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusPill.leadingAnchor, constant: -8),

            dateLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: idLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusPill.leadingAnchor, constant: -8),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with record: BGTaskRecord) {
        idLabel.text   = record.identifier
        typeLabel.text = record.type.rawValue

        if record.isPending {
            statusPill.text            = "  PENDING  "
            statusPill.backgroundColor = UIColor.Phantom.vibrantOrange
            accentStrip.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
            iconBg.backgroundColor     = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.12)
            iconView.tintColor         = UIColor.Phantom.vibrantOrange
        } else {
            statusPill.text            = "  IDLE  "
            statusPill.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            accentStrip.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.6)
            iconBg.backgroundColor     = PhantomTheme.shared.primaryColor.withAlphaComponent(0.1)
            iconView.tintColor         = PhantomTheme.shared.primaryColor
        }

        if let begin = record.earliestBeginDate {
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .medium
            dateLabel.text      = "Earliest begin: \(df.string(from: begin))"
            dateLabel.textColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
        } else if let seen = record.lastSeenPending {
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .medium
            dateLabel.text      = "Last pending: \(df.string(from: seen))"
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        } else {
            dateLabel.text      = "Never submitted"
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.25)
        }
    }
}

// MARK: - BGTaskDetailVC

@available(iOS 13.0, *)
private final class BGTaskDetailVC: UITableViewController {

    private let record: BGTaskRecord

    init(record: BGTaskRecord) {
        self.record = record
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = record.identifier.components(separatedBy: ".").last ?? "Task Detail"
        tableView.allowsSelection = false
        applyDarkAppearance()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain, target: self, action: #selector(copyTapped)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phantom_applyNavBarAppearance(tintColor: UIColor.Phantom.vibrantOrange)
    }

    private func applyDarkAppearance() {
        tableView.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.06)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
    }

    private var rows: [(String, String)] {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium

        var result: [(String, String)] = [
            ("Identifier",    record.identifier),
            ("Type",          record.type.rawValue),
            ("Status",        record.isPending ? "Pending" : "Idle"),
        ]
        if let begin = record.earliestBeginDate {
            result.append(("Earliest Begin", df.string(from: begin)))
        }
        if let seen = record.lastSeenPending {
            result.append(("Last Seen Pending", df.string(from: seen)))
        }
        result.append(("Last Refreshed", df.string(from: record.lastRefreshed)))
        return result
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let wrapper = UIView()
        wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
        let label = UILabel()
        label.text      = "TASK INFO"
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
        ])
        return wrapper
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle  = .none
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        let (key, value) = rows[indexPath.row]

        cell.textLabel?.text      = key.uppercased()
        cell.textLabel?.font      = UIFont.systemFont(ofSize: 10, weight: .semibold)
        cell.textLabel?.textColor = UIColor.white.withAlphaComponent(0.35)

        cell.detailTextLabel?.text          = value
        cell.detailTextLabel?.font          = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor     = UIColor.white.withAlphaComponent(0.9)
        cell.detailTextLabel?.numberOfLines = 0
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    @objc private func copyTapped() {
        let text = rows.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
        UIPasteboard.general.string = text
        navigationItem.rightBarButtonItem?.image = UIImage(systemName: "checkmark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.navigationItem.rightBarButtonItem?.image = UIImage(systemName: "doc.on.doc")
        }
    }
}
#endif
