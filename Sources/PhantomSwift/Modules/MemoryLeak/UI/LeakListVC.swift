#if DEBUG
import UIKit

// MARK: - LeakListVC

internal final class LeakListVC: PhantomTableVC, PhantomEventObserver {

    // MARK: - State

    private var allLeaks: [LeakReport] = []
    private var filteredLeaks: [LeakReport] = []
    private var searchText: String = ""

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    private enum Section: Int, CaseIterable {
        case critical   // .critical + .confirmed
        case potential  // .potential
    }

    private var criticalLeaks: [LeakReport] {
        filteredLeaks.filter { $0.severity != .potential }
    }
    private var potentialLeaks: [LeakReport] {
        filteredLeaks.filter { $0.severity == .potential }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Memory Leaks"

        // Load persisted reports
        allLeaks = PhantomLeakTracker.shared.reports
        applyFilter()

        tableView.register(LeakCell.self, forCellReuseIdentifier: LeakCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)

        searchBar.delegate = self
        setupNavigation()

        PhantomEventBus.shared.subscribe(self, to: "memoryLeakDetected")
    }

    // MARK: - Navigation

    private func setupNavigation() {
        if #available(iOS 13.0, *) {
            let trash = UIBarButtonItem(
                image: UIImage(systemName: "trash"), style: .plain,
                target: self, action: #selector(clearAll))
            let share = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"), style: .plain,
                target: self, action: #selector(exportJSON))
            let heap = UIBarButtonItem(
                image: UIImage(systemName: "camera.viewfinder"), style: .plain,
                target: self, action: #selector(openHeapSnapshot))
            trash.tintColor = UIColor.Phantom.vibrantRed
            share.tintColor = UIColor.Phantom.neonAzure
            navigationItem.rightBarButtonItems = [trash, share]
            navigationItem.leftBarButtonItem = heap
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Clear", style: .plain, target: self, action: #selector(clearAll))
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Heap", style: .plain, target: self, action: #selector(openHeapSnapshot))
        }
    }

    // MARK: - Actions

    @objc private func clearAll() {
        PhantomLeakTracker.shared.clearReports()
        allLeaks.removeAll()
        filteredLeaks.removeAll()
        tableView.reloadData()
    }

    @objc private func exportJSON() {
        var arr: [[String: Any]] = []
        for r in allLeaks {
            arr.append([
                "id": r.id.uuidString,
                "className": r.className,
                "displayName": r.displayName,
                "severity": r.severity.rawValue,
                "address": r.objectAddress,
                "retainCount": r.retainCount,
                "timestamp": r.timestamp.timeIntervalSince1970,
                "file": r.file ?? "",
                "line": r.line ?? 0,
                "callStack": r.callStack.prefix(10).map { $0 }
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return }
        let vc = UIActivityViewController(activityItems: [str], applicationActivities: nil)
        present(vc, animated: true)
    }

    @objc private func openHeapSnapshot() {
        let vc = HeapSnapshotVC()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Filtering

    private func applyFilter() {
        let q = searchText.lowercased()
        if q.isEmpty {
            filteredLeaks = allLeaks
        } else {
            filteredLeaks = allLeaks.filter {
                $0.className.lowercased().contains(q) ||
                $0.displayName.lowercased().contains(q) ||
                $0.objectAddress.lowercased().contains(q)
            }
        }
        tableView.reloadData()
    }

    // MARK: - PhantomEventObserver

    func onEvent(_ event: PhantomEvent) {
        guard case .memoryLeakDetected(let report) = event else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Deduplicate by address + severity
            let isDup = self.allLeaks.contains {
                $0.objectAddress == report.objectAddress && $0.severity == report.severity
            }
            guard !isDup else { return }
            self.allLeaks.insert(report, at: 0)
            self.applyFilter()
        }
    }

    // MARK: - PhantomTableVC Overrides

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == Section.critical.rawValue ? criticalLeaks.count : potentialLeaks.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == Section.critical.rawValue {
            let count = criticalLeaks.count
            return count > 0 ? "🔴 CONFIRMED / CRITICAL (\(count))" : nil
        } else {
            let count = potentialLeaks.count
            return count > 0 ? "🟡 POTENTIAL (\(count))" : nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LeakCell.reuseID, for: indexPath) as! LeakCell
        let leak = indexPath.section == Section.critical.rawValue
            ? criticalLeaks[indexPath.row]
            : potentialLeaks[indexPath.row]
        cell.configure(with: leak, formatter: fmt)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let leak = indexPath.section == Section.critical.rawValue
            ? criticalLeaks[indexPath.row]
            : potentialLeaks[indexPath.row]
        navigationController?.pushViewController(LeakDetailVC(leak: leak), animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - Swipe-to-delete

extension LeakListVC {
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let leak = indexPath.section == Section.critical.rawValue
            ? criticalLeaks[indexPath.row]
            : potentialLeaks[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.allLeaks.removeAll { $0.id == leak.id }
            self?.applyFilter()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [del])
    }
}

// MARK: - UISearchBarDelegate

extension LeakListVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - LeakCell

private final class LeakCell: UITableViewCell {
    static let reuseID = "LeakCell"

    private let severityBar  = UIView()
    private let classLabel   = UILabel()
    private let addressLabel = UILabel()
    private let timeLabel    = UILabel()
    private let retainBadge  = PaddedLabel()
    private let sevBadge     = PaddedLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor  = .clear
        selectionStyle   = .none
        accessoryType    = .disclosureIndicator

        severityBar.layer.cornerRadius = 2
        severityBar.translatesAutoresizingMaskIntoConstraints = false

        classLabel.font      = .systemFont(ofSize: 14, weight: .bold)
        classLabel.textColor = PhantomTheme.shared.textColor
        classLabel.numberOfLines = 1
        classLabel.translatesAutoresizingMaskIntoConstraints = false

        sevBadge.font              = .systemFont(ofSize: 9, weight: .black)
        sevBadge.layer.cornerRadius = 4
        sevBadge.layer.masksToBounds = true
        sevBadge.textAlignment     = .center
        sevBadge.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.font      = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        addressLabel.textColor = UIColor.Phantom.neonAzure
        addressLabel.translatesAutoresizingMaskIntoConstraints = false

        retainBadge.font              = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        retainBadge.layer.cornerRadius = 4
        retainBadge.layer.masksToBounds = true
        retainBadge.textAlignment     = .center
        retainBadge.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font      = .systemFont(ofSize: 11)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        [severityBar, classLabel, sevBadge, addressLabel, retainBadge, timeLabel].forEach {
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            severityBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            severityBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            severityBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            severityBar.widthAnchor.constraint(equalToConstant: 4),

            classLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            classLabel.leadingAnchor.constraint(equalTo: severityBar.trailingAnchor, constant: 12),

            sevBadge.centerYAnchor.constraint(equalTo: classLabel.centerYAnchor),
            sevBadge.leadingAnchor.constraint(equalTo: classLabel.trailingAnchor, constant: 6),
            sevBadge.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            sevBadge.heightAnchor.constraint(equalToConstant: 16),

            addressLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: severityBar.trailingAnchor, constant: 12),

            retainBadge.centerYAnchor.constraint(equalTo: addressLabel.centerYAnchor),
            retainBadge.leadingAnchor.constraint(equalTo: addressLabel.trailingAnchor, constant: 8),
            retainBadge.heightAnchor.constraint(equalToConstant: 16),

            timeLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: severityBar.trailingAnchor, constant: 12),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with leak: LeakReport, formatter: DateFormatter) {
        classLabel.text  = leak.displayName == leak.className
            ? leak.className
            : "\(leak.displayName) (\(leak.className))"
        addressLabel.text = leak.objectAddress
        timeLabel.text    = formatter.string(from: leak.timestamp)
        retainBadge.text  = " RC:\(leak.retainCount) "

        let (barColor, badgeText, badgeColor): (UIColor, String, UIColor)
        switch leak.severity {
        case .critical:
            barColor = UIColor.Phantom.vibrantRed
            badgeText = " CRITICAL "
            badgeColor = UIColor.Phantom.vibrantRed
        case .confirmed:
            barColor = UIColor.Phantom.vibrantOrange
            badgeText = " CONFIRMED "
            badgeColor = UIColor.Phantom.vibrantOrange
        case .potential:
            barColor = UIColor.systemYellow
            badgeText = " POTENTIAL "
            badgeColor = UIColor.systemYellow
        }

        severityBar.backgroundColor = barColor
        sevBadge.text                = badgeText
        sevBadge.backgroundColor     = badgeColor.withAlphaComponent(0.15)
        sevBadge.textColor           = badgeColor
        retainBadge.backgroundColor  = UIColor.Phantom.electricIndigo.withAlphaComponent(0.15)
        retainBadge.textColor        = UIColor.Phantom.electricIndigo
    }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}

// MARK: - LeakDetailVC

internal final class LeakDetailVC: UIViewController {

    private let leak: LeakReport
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    init(leak: LeakReport) {
        self.leak = leak
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = leak.displayName
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupScrollView()
        buildContent()
        setupNav()
    }

    private func setupNav() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "network"),
                style: .plain,
                target: self,
                action: #selector(openRetainGraph))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Graph", style: .plain,
                target: self, action: #selector(openRetainGraph))
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantPurple
    }

    @objc private func openRetainGraph() {
        navigationController?.pushViewController(ObjectRetainGraphVC(leak: leak), animated: true)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildContent() {
        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])

        // Header card
        stack.addArrangedSubview(buildHeaderCard())

        // Mirror properties
        if !leak.mirroredProperties.isEmpty {
            stack.addArrangedSubview(buildSectionLabel("RETAINED PROPERTIES"))
            stack.addArrangedSubview(buildPropertiesCard())
        }

        // Call stack
        if !leak.callStack.isEmpty {
            stack.addArrangedSubview(buildSectionLabel("CALL STACK AT TRACKING"))
            let codeView = PhantomCodeView()
            codeView.text = leak.callStack.prefix(30).joined(separator: "\n")
            stack.addArrangedSubview(codeView)
        }
    }

    private func buildHeaderCard() -> UIView {
        let card = UIView()
        card.backgroundColor   = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 12

        let rows: [(String, String, UIColor)] = [
            ("Class",    leak.className,      PhantomTheme.shared.textColor),
            ("Address",  leak.objectAddress,  UIColor.Phantom.neonAzure),
            ("Severity", leak.severity.rawValue.uppercased(), severityColor),
            ("RC",       "\(leak.retainCount)", UIColor.Phantom.electricIndigo),
            ("Time",     DateFormatter.localizedString(from: leak.timestamp, dateStyle: .none, timeStyle: .medium), PhantomTheme.shared.textColor.withAlphaComponent(0.6)),
            ("File",     fileInfo, PhantomTheme.shared.textColor.withAlphaComponent(0.6)),
        ]

        let vstack = UIStackView()
        vstack.axis    = .vertical
        vstack.spacing = 8
        vstack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            vstack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            vstack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            vstack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        for (key, value, color) in rows {
            let row = UIStackView()
            row.spacing = 8
            let kl = UILabel()
            kl.text      = key
            kl.font      = .systemFont(ofSize: 11, weight: .semibold)
            kl.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
            kl.setContentHuggingPriority(.required, for: .horizontal)
            kl.widthAnchor.constraint(equalToConstant: 70).isActive = true
            let vl = UILabel()
            vl.text          = value
            vl.font          = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            vl.textColor     = color
            vl.numberOfLines = 2
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            vstack.addArrangedSubview(row)
        }
        return card
    }

    private func buildPropertiesCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 12

        let vstack = UIStackView()
        vstack.axis    = .vertical
        vstack.spacing = 6
        vstack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            vstack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            vstack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            vstack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        for (label, value) in leak.mirroredProperties.prefix(15) {
            let row = UIStackView()
            row.spacing = 6
            let kl = UILabel()
            kl.text      = label
            kl.font      = .systemFont(ofSize: 11, weight: .medium)
            kl.textColor = UIColor.Phantom.vibrantGreen
            kl.setContentHuggingPriority(.required, for: .horizontal)
            kl.widthAnchor.constraint(equalToConstant: 110).isActive = true
            let vl = UILabel()
            vl.text          = value
            vl.font          = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            vl.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.75)
            vl.numberOfLines = 2
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            vstack.addArrangedSubview(row)
        }
        return card
    }

    private func buildSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = .systemFont(ofSize: 10, weight: .black)
        l.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.7)
        return l
    }

    private var severityColor: UIColor {
        switch leak.severity {
        case .critical:  return UIColor.Phantom.vibrantRed
        case .confirmed: return UIColor.Phantom.vibrantOrange
        case .potential: return UIColor.systemYellow
        }
    }

    private var fileInfo: String {
        guard let f = leak.file else { return "—" }
        let base = (f as NSString).lastPathComponent
        if let l = leak.line { return "\(base):\(l)" }
        return base
    }
}
#endif

