#if DEBUG
import UIKit

// MARK: - AnalyticsListVC

internal final class AnalyticsListVC: UIViewController {

    // MARK: - Mode

    private enum Mode: Int { case feed = 0, byProvider = 1 }
    private var mode: Mode = .feed

    // MARK: - State

    private var feedEvents:   [PhantomAnalyticsEvent] = []   // flat, most recent first
    private var providers:    [String] = []                  // sorted provider names
    private var providerRows: [[PhantomAnalyticsEvent]] = [] // per-provider events
    private var searchText:   String = ""

    // MARK: - UI

    private let segment   = UISegmentedControl(items: ["FEED", "BY PROVIDER"])
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statsBar  = UIView()
    private let totalLbl  = UILabel()
    private let provLbl   = UILabel()

    @available(iOS 13.0, *)
    private static var sharedFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    private static let legacyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics Feed"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildUI()
        reloadData()
        NotificationCenter.default.addObserver(self,
            selector: #selector(onUpdated),
            name: .phantomAnalyticsUpdated,
            object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Build UI

    private func buildUI() {
        // Segment control
        segment.selectedSegmentIndex = 0
        segment.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) { segment.selectedSegmentTintColor = UIColor.Phantom.neonAzure }
        segment.tintColor = UIColor.Phantom.neonAzure
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        // Stats bar
        statsBar.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.6)
        statsBar.translatesAutoresizingMaskIntoConstraints = false

        totalLbl.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        totalLbl.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        totalLbl.translatesAutoresizingMaskIntoConstraints = false

        provLbl.font      = .systemFont(ofSize: 11)
        provLbl.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        provLbl.translatesAutoresizingMaskIntoConstraints = false

        statsBar.addSubview(totalLbl)
        statsBar.addSubview(provLbl)

        // Search
        searchBar.barStyle       = PhantomTheme.shared.currentTheme == .light ? .default : .black
        searchBar.placeholder    = "Search events, providers…"
        searchBar.delegate       = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)

        // Table
        tableView.backgroundColor   = .clear
        tableView.dataSource        = self
        tableView.delegate          = self
        tableView.register(AnalyticsEventCell.self, forCellReuseIdentifier: AnalyticsEventCell.reuseID)
        tableView.rowHeight            = UITableView.automaticDimension
        tableView.estimatedRowHeight   = 72
        tableView.tableFooterView      = UIView()
        tableView.separatorColor       = PhantomTheme.shared.textColor.withAlphaComponent(0.08)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        // Nav buttons
        if #available(iOS 13.0, *) {
            let clearBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearAll))
            let exportBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportJSON))
            clearBtn.tintColor  = UIColor.Phantom.vibrantRed
            exportBtn.tintColor = UIColor.Phantom.neonAzure
            navigationItem.rightBarButtonItems = [clearBtn, exportBtn]
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearAll))
        }

        [segment, statsBar, searchBar, tableView].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statsBar.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 8),
            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBar.heightAnchor.constraint(equalToConstant: 30),

            totalLbl.leadingAnchor.constraint(equalTo: statsBar.leadingAnchor, constant: 16),
            totalLbl.centerYAnchor.constraint(equalTo: statsBar.centerYAnchor),

            provLbl.trailingAnchor.constraint(equalTo: statsBar.trailingAnchor, constant: -16),
            provLbl.centerYAnchor.constraint(equalTo: statsBar.centerYAnchor),

            searchBar.topAnchor.constraint(equalTo: statsBar.bottomAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data

    @objc private func onUpdated() { reloadData() }

    private func reloadData() {
        let all = PhantomAnalyticsMonitor.shared.events(for: nil) // most recent first
        let provs = PhantomAnalyticsMonitor.shared.allProviders()
        let freq  = PhantomAnalyticsMonitor.shared.frequencyMap()
        let q = searchText.lowercased()

        // Feed mode
        feedEvents = q.isEmpty ? all : all.filter {
            $0.name.lowercased().contains(q) ||
            $0.provider.lowercased().contains(q) ||
            $0.parameters.values.contains(where: { $0.lowercased().contains(q) })
        }

        // By provider mode
        providers = provs
        providerRows = provs.map { p in
            let rows = PhantomAnalyticsMonitor.shared.events(for: p)
            if q.isEmpty { return rows }
            return rows.filter {
                $0.name.lowercased().contains(q) ||
                $0.parameters.values.contains(where: { $0.lowercased().contains(q) })
            }
        }

        // Stats
        let total = PhantomAnalyticsMonitor.shared.events.count
        totalLbl.text = "\(total) events captured"
        provLbl.text  = "\(provs.count) provider\(provs.count == 1 ? "" : "s")"

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        mode = Mode(rawValue: segment.selectedSegmentIndex) ?? .feed
        tableView.reloadData()
    }

    @objc private func clearAll() {
        PhantomAnalyticsMonitor.shared.clear()
        reloadData()
    }

    @objc private func exportJSON() {
        let all = PhantomAnalyticsMonitor.shared.events(for: nil)
        let arr: [[String: Any]] = all.map { e in
            ["id": e.id, "name": e.name, "provider": e.provider,
             "timestamp": e.timestamp.timeIntervalSince1970,
             "parameters": e.parameters]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return }
        let vc = UIActivityViewController(activityItems: [str], applicationActivities: nil)
        present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource + Delegate

extension AnalyticsListVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        mode == .feed ? 1 : providers.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        mode == .feed ? feedEvents.count : providerRows[safe: section]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard mode == .byProvider, section < providers.count else { return nil }
        let provider = providers[section]
        let count    = providerRows[safe: section]?.count ?? 0
        return makeProviderHeader(provider: provider, count: count)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        mode == .byProvider ? 36 : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AnalyticsEventCell.reuseID, for: indexPath) as! AnalyticsEventCell
        let event = eventAt(indexPath)
        if #available(iOS 13.0, *) {
            cell.configure(with: event, formatter: AnalyticsListVC.sharedFmt, legacyFormatter: nil)
        } else {
            cell.configure(with: event, formatter: nil, legacyFormatter: AnalyticsListVC.legacyFormatter)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(AnalyticsDetailVC(event: eventAt(indexPath)), animated: true)
    }

    private func eventAt(_ indexPath: IndexPath) -> PhantomAnalyticsEvent {
        if mode == .feed { return feedEvents[indexPath.row] }
        return providerRows[indexPath.section][indexPath.row]
    }

    private func makeProviderHeader(provider: String, count: Int) -> UIView {
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.5)
        let accent = PhantomAnalyticsMonitor.color(for: provider)

        let bar = UIView()
        bar.backgroundColor  = accent
        bar.layer.cornerRadius = 1
        bar.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(bar)

        let lbl = UILabel()
        lbl.text      = provider.uppercased()
        lbl.font      = .systemFont(ofSize: 10, weight: .black)
        lbl.textColor = accent
        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)

        let cntLbl = UILabel()
        cntLbl.text      = "\(count)"
        cntLbl.font      = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        cntLbl.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        cntLbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(cntLbl)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            bar.topAnchor.constraint(equalTo: v.topAnchor),
            bar.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 3),
            lbl.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 14),
            lbl.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            cntLbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            cntLbl.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        return v
    }
}

// MARK: - UISearchBarDelegate

extension AnalyticsListVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        reloadData()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

// MARK: - AnalyticsEventCell

private final class AnalyticsEventCell: UITableViewCell {
    static let reuseID = "AnalyticsEventCell"

    private let providerBadge = PillLabel()
    private let nameLabel     = UILabel()
    private let paramBadge    = PillLabel()
    private let timeLabel     = UILabel()
    private let accentBar     = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .default
        accessoryType   = .disclosureIndicator

        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font      = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = PhantomTheme.shared.textColor
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        providerBadge.translatesAutoresizingMaskIntoConstraints = false
        paramBadge.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font      = .systemFont(ofSize: 11)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.45)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        [accentBar, nameLabel, providerBadge, paramBadge, timeLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            accentBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            providerBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            providerBadge.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),

            nameLabel.topAnchor.constraint(equalTo: providerBadge.bottomAnchor, constant: 5),
            nameLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),

            paramBadge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            paramBadge.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),

            timeLabel.centerYAnchor.constraint(equalTo: paramBadge.centerYAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: paramBadge.trailingAnchor, constant: 8),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with event: PhantomAnalyticsEvent, formatter: AnyObject?, legacyFormatter: DateFormatter?) {
        let accent = PhantomAnalyticsMonitor.color(for: event.provider)
        accentBar.backgroundColor = accent

        providerBadge.label.text            = event.provider.uppercased()
        providerBadge.label.font            = .systemFont(ofSize: 9, weight: .black)
        providerBadge.label.textColor       = accent
        providerBadge.backgroundColor       = accent.withAlphaComponent(0.12)
        providerBadge.layer.cornerRadius    = 4

        nameLabel.text = event.name

        let pc = event.parameters.count
        paramBadge.label.text         = pc == 0 ? "No params" : "\(pc) param\(pc == 1 ? "" : "s")"
        paramBadge.label.font         = .systemFont(ofSize: 10, weight: .semibold)
        paramBadge.label.textColor    = UIColor.Phantom.electricIndigo
        paramBadge.backgroundColor    = UIColor.Phantom.electricIndigo.withAlphaComponent(0.12)
        paramBadge.layer.cornerRadius = 4

        if #available(iOS 13.0, *), let rel = formatter as? RelativeDateTimeFormatter {
            timeLabel.text = rel.localizedString(for: event.timestamp, relativeTo: Date())
        } else {
            timeLabel.text = legacyFormatter?.string(from: event.timestamp) ?? ""
        }
    }
}

// MARK: - PillLabel (inset label)

private final class PillLabel: UIView {
    let label = UILabel()
    private let insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ])
        layer.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - AnalyticsDetailVC

internal final class AnalyticsDetailVC: UIViewController {

    private let event: PhantomAnalyticsEvent
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var sortedParams: [(key: String, value: String)] = []

    init(event: PhantomAnalyticsEvent) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = event.name
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        sortedParams = event.parameters.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
        buildUI()
    }

    private func buildUI() {
        tableView.backgroundColor    = .clear
        tableView.dataSource         = self
        tableView.delegate           = self
        tableView.rowHeight            = UITableView.automaticDimension
        tableView.estimatedRowHeight   = 44
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ParamCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InfoCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "doc.on.clipboard"), style: .plain,
                target: self, action: #selector(copyJSON))
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.neonAzure
    }

    @objc private func copyJSON() {
        let dict: [String: Any] = [
            "name": event.name, "provider": event.provider,
            "timestamp": event.timestamp.timeIntervalSince1970,
            "parameters": event.parameters
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = str
        }
    }
}

extension AnalyticsDetailVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 3 : max(sortedParams.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "EVENT INFO" : "PARAMETERS (\(sortedParams.count))"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font      = .systemFont(ofSize: 10, weight: .black)
        header.textLabel?.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.7)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InfoCell", for: indexPath)
            cell.backgroundColor = PhantomTheme.shared.surfaceColor
            cell.selectionStyle  = .none
            let (key, value, color): (String, String, UIColor)
            switch indexPath.row {
            case 0: (key, value, color) = ("Event",    event.name,     PhantomTheme.shared.textColor)
            case 1: (key, value, color) = ("Provider", event.provider, PhantomAnalyticsMonitor.color(for: event.provider))
            default:
                let f = DateFormatter()
                f.dateStyle = .medium; f.timeStyle = .long
                (key, value, color) = ("Time", f.string(from: event.timestamp), PhantomTheme.shared.textColor.withAlphaComponent(0.7))
            }
            if #available(iOS 14.0, *) {
                var cfg = cell.defaultContentConfiguration()
                cfg.text                       = key
                cfg.textProperties.color       = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
                cfg.textProperties.font        = .systemFont(ofSize: 11, weight: .semibold)
                cfg.secondaryText              = value
                cfg.secondaryTextProperties.color = color
                cfg.secondaryTextProperties.font  = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
                cell.contentConfiguration = cfg
            } else {
                cell.textLabel?.text          = key
                cell.textLabel?.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
                cell.detailTextLabel?.text    = value
                cell.detailTextLabel?.textColor = color
            }
            return cell
        }

        // Parameters
        let cell = tableView.dequeueReusableCell(withIdentifier: "ParamCell", for: indexPath)
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        cell.selectionStyle  = .default
        if sortedParams.isEmpty {
            cell.textLabel?.text      = "No parameters"
            cell.textLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
            cell.selectionStyle       = .none
            return cell
        }
        let param = sortedParams[indexPath.row]
        if #available(iOS 14.0, *) {
            var cfg = cell.defaultContentConfiguration()
            cfg.text                      = param.key
            cfg.textProperties.color      = UIColor.Phantom.vibrantGreen
            cfg.textProperties.font       = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            cfg.secondaryText             = param.value
            cfg.secondaryTextProperties.color = PhantomTheme.shared.textColor.withAlphaComponent(0.75)
            cfg.secondaryTextProperties.font  = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            cfg.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = cfg
        } else {
            cell.textLabel?.text       = param.key
            cell.textLabel?.textColor  = UIColor.Phantom.vibrantGreen
            cell.detailTextLabel?.text = param.value
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, !sortedParams.isEmpty else { return }
        let param = sortedParams[indexPath.row]
        UIPasteboard.general.string = "\(param.key): \(param.value)"
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
