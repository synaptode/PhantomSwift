#if DEBUG
import UIKit

// MARK: - HeapSnapshotVC

/// Visualizes heap instance count differences between two snapshots.
/// Tap "Baseline" to capture a reference state, then "Compare" to see growth.
internal final class HeapSnapshotVC: UIViewController {

    // MARK: - State

    private var baseline: [String: Int] = [:]
    private var current: [String: Int] = [:]
    private var rows: [DeltaRow] = []
    private var filteredRows: [DeltaRow] = []
    private var searchText: String = ""
    private var isCapturing = false

    fileprivate struct DeltaRow {
        let className: String
        let before: Int
        let after: Int
        var delta: Int { after - before }
    }

    // MARK: - UI

    private let tableView  = UITableView(frame: .zero, style: .plain)
    private let searchBar  = UISearchBar()
    private let toolbar    = UIView()
    private let baseBtn    = UIButton(type: .system)
    private let compareBtn = UIButton(type: .system)
    private let statusLbl  = UILabel()
    private let activityIndicator = UIActivityIndicatorView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Heap Snapshot"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildUI()
    }

    // MARK: - Layout

    private func buildUI() {
        // Toolbar
        toolbar.backgroundColor = PhantomTheme.shared.surfaceColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        configButton(baseBtn,    title: "📷  Set Baseline", color: UIColor.Phantom.neonAzure)
        configButton(compareBtn, title: "🔍  Compare Now",  color: UIColor.Phantom.vibrantGreen)
        compareBtn.isEnabled = false
        baseBtn.addTarget(self, action: #selector(captureBaseline), for: .touchUpInside)
        compareBtn.addTarget(self, action: #selector(compareNow), for: .touchUpInside)

        if #available(iOS 13.0, *) {
            activityIndicator.style = .medium
        } else {
            activityIndicator.style = .gray
        }
        activityIndicator.color = UIColor.Phantom.neonAzure
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusLbl.font      = .systemFont(ofSize: 11)
        statusLbl.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        statusLbl.text      = "Capture a baseline first"
        statusLbl.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = UIStackView(arrangedSubviews: [baseBtn, compareBtn])
        btnStack.spacing     = 12
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        toolbar.addSubview(btnStack)
        toolbar.addSubview(statusLbl)
        toolbar.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            btnStack.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 10),
            btnStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            btnStack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            btnStack.heightAnchor.constraint(equalToConstant: 44),

            statusLbl.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 6),
            statusLbl.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            statusLbl.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -10),

            activityIndicator.centerYAnchor.constraint(equalTo: statusLbl.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
        ])

        // Search bar
        searchBar.barStyle       = PhantomTheme.shared.currentTheme == .light ? .default : .black
        searchBar.placeholder    = "Filter classes…"
        searchBar.delegate       = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)

        // Table
        tableView.backgroundColor = .clear
        tableView.dataSource      = self
        tableView.delegate        = self
        tableView.register(DeltaCell.self, forCellReuseIdentifier: DeltaCell.reuseID)
        tableView.rowHeight            = UITableView.automaticDimension
        tableView.estimatedRowHeight   = 56
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView      = UIView()
        tableView.separatorColor       = PhantomTheme.shared.textColor.withAlphaComponent(0.1)

        [toolbar, searchBar, tableView].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            searchBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configButton(_ btn: UIButton, title: String, color: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font    = .systemFont(ofSize: 14, weight: .semibold)
        btn.tintColor           = color
        btn.backgroundColor     = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius  = 10
        btn.contentEdgeInsets   = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    }

    // MARK: - Actions

    @objc private func captureBaseline() {
        guard !isCapturing else { return }
        isCapturing = true
        baseBtn.isEnabled    = false
        compareBtn.isEnabled = false
        activityIndicator.startAnimating()
        statusLbl.text = "Sweeping heap…"

        PhantomHeapSnapshot.captureAsync { [weak self] _ in
            // Call instanceCounts on background already, result comes here
            let counts = PhantomHeapSnapshot.instanceCounts()
            DispatchQueue.main.async {
                guard let self else { return }
                self.baseline    = counts
                self.current     = [:]
                self.rows        = []
                self.filteredRows = []
                self.tableView.reloadData()
                self.isCapturing       = false
                self.baseBtn.isEnabled    = true
                self.compareBtn.isEnabled = true
                self.activityIndicator.stopAnimating()
                self.statusLbl.text = "Baseline: \(counts.count) classes. Tap Compare."
            }
        }
    }

    @objc private func compareNow() {
        guard !baseline.isEmpty, !isCapturing else { return }
        isCapturing = true
        baseBtn.isEnabled    = false
        compareBtn.isEnabled = false
        activityIndicator.startAnimating()
        statusLbl.text = "Comparing…"

        PhantomHeapSnapshot.captureAsync { [weak self] _ in
            let counts = PhantomHeapSnapshot.instanceCounts()
            DispatchQueue.main.async {
                guard let self else { return }
                self.current = counts

                // Build delta rows — only show classes with any instances in either snapshot
                let allKeys = Set(self.baseline.keys).union(counts.keys)
                var deltaRows: [DeltaRow] = allKeys.compactMap { cls in
                    let before = self.baseline[cls] ?? 0
                    let after  = counts[cls] ?? 0
                    guard before > 0 || after > 0 else { return nil }
                    return DeltaRow(className: cls, before: before, after: after)
                }
                // Sort: largest delta first, then by class name
                deltaRows.sort {
                    if $0.delta != $1.delta { return $0.delta > $1.delta }
                    return $0.className < $1.className
                }
                self.rows = deltaRows

                var growCount = 0
                var newCount = 0
                for row in deltaRows {
                    if row.delta > 0 {
                        growCount += 1
                        if row.before == 0 {
                            newCount += 1
                        }
                    }
                }
                self.statusLbl.text = "\(growCount) growing classes, \(newCount) new"
                self.isCapturing        = false
                self.baseBtn.isEnabled    = true
                self.compareBtn.isEnabled = true
                self.activityIndicator.stopAnimating()
                self.applyFilter()
            }
        }
    }

    private func applyFilter() {
        let q = searchText.lowercased()
        filteredRows = q.isEmpty ? rows : rows.filter { $0.className.lowercased().contains(q) }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource + Delegate

extension HeapSnapshotVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredRows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !rows.isEmpty else { return nil }
        return "\(filteredRows.count) classes  (sorted by Δ)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeltaCell.reuseID, for: indexPath) as! DeltaCell
        cell.configure(with: filteredRows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = filteredRows[indexPath.row]
        UIPasteboard.general.string = row.className
    }
}

// MARK: - UISearchBarDelegate

extension HeapSnapshotVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - DeltaCell

private final class DeltaCell: UITableViewCell {
    static let reuseID = "DeltaCell"

    private let classLabel  = UILabel()
    private let beforeLabel = UILabel()
    private let afterLabel  = UILabel()
    private let deltaLabel  = PaddedBadge()
    private let barTrack    = UIView()
    private let barFill     = UIView()
    private var barWidthConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .none

        classLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        classLabel.textColor = PhantomTheme.shared.textColor
        classLabel.numberOfLines = 1

        beforeLabel.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        beforeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        beforeLabel.textAlignment = .right

        afterLabel.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        afterLabel.textColor = PhantomTheme.shared.textColor
        afterLabel.textAlignment = .right

        deltaLabel.font              = .monospacedDigitSystemFont(ofSize: 11, weight: .black)
        deltaLabel.textAlignment     = .center
        deltaLabel.layer.cornerRadius = 6
        deltaLabel.layer.masksToBounds = true

        barTrack.backgroundColor   = PhantomTheme.shared.textColor.withAlphaComponent(0.08)
        barTrack.layer.cornerRadius = 2

        barFill.layer.cornerRadius = 2

        let metaRow = UIStackView(arrangedSubviews: [beforeLabel, afterLabel, deltaLabel])
        metaRow.spacing = 8
        metaRow.alignment = .center

        let topRow = UIStackView(arrangedSubviews: [classLabel, metaRow])
        topRow.spacing = 4
        topRow.alignment = .center

        [topRow, barTrack, barFill].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        barWidthConstraint = barFill.widthAnchor.constraint(equalToConstant: 0)
        barWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            deltaLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            deltaLabel.heightAnchor.constraint(equalToConstant: 20),
            beforeLabel.widthAnchor.constraint(equalToConstant: 44),
            afterLabel.widthAnchor.constraint(equalToConstant: 44),

            barTrack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            barTrack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            barTrack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            barTrack.heightAnchor.constraint(equalToConstant: 4),
            barTrack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.heightAnchor.constraint(equalTo: barTrack.heightAnchor),
        ])
    }

    func configure(with row: HeapSnapshotVC.DeltaRow) {
        classLabel.text  = row.className
        beforeLabel.text = row.before == 0 ? "—" : "\(row.before)"
        afterLabel.text  = "\(row.after)"

        let delta = row.delta
        let deltaText: String
        let fillColor: UIColor
        let badgeColor: UIColor

        if row.before == 0 {
            // Newly appeared class
            deltaText  = " NEW "
            fillColor  = UIColor.Phantom.vibrantOrange
            badgeColor = UIColor.Phantom.vibrantOrange
        } else if delta > 0 {
            deltaText  = " +\(delta) "
            fillColor  = UIColor.Phantom.vibrantRed
            badgeColor = UIColor.Phantom.vibrantRed
        } else if delta < 0 {
            deltaText  = " \(delta) "
            fillColor  = UIColor.Phantom.vibrantGreen
            badgeColor = UIColor.Phantom.vibrantGreen
        } else {
            deltaText  = " ±0 "
            fillColor  = PhantomTheme.shared.textColor.withAlphaComponent(0.2)
            badgeColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        }

        deltaLabel.text            = deltaText
        deltaLabel.backgroundColor = badgeColor.withAlphaComponent(0.15)
        deltaLabel.textColor       = badgeColor
        barFill.backgroundColor    = fillColor

        // Bar proportional to (after / max(after, 200))
        let maxExpected: CGFloat = max(CGFloat(row.after), 1)
        let ratio = min(CGFloat(row.after) / max(maxExpected, 200), 1.0)
        setNeedsLayout()
        layoutIfNeeded()
        let trackW = barTrack.bounds.width
        barWidthConstraint?.constant = trackW * ratio
    }
}

// MARK: - PaddedBadge

private final class PaddedBadge: UILabel {
    private let pad = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: pad)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + pad.left + pad.right,
                      height: s.height + pad.top + pad.bottom)
    }
}

#endif
