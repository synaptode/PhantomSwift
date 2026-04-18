#if DEBUG
import UIKit

/// Before/after memory diff viewer.
/// Lets the developer capture a "before" baseline, interact with the app,
/// then capture "after" to see exactly which objects were newly allocated.
internal final class MemoryDiffVC: UIViewController {

    // MARK: - State

    private var diffedObjects: [PhantomTrackedObject] = []
    private var refreshTimer: Timer?

    // MARK: - Header views

    private let headerCard  = UIView()
    private let beforeLabel = UILabel()
    private let afterLabel  = UILabel()
    private let deltaLabel  = UILabel()

    // MARK: - Table

    private let tableView  = UITableView(frame: .zero, style: .grouped)
    private let emptyLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Memory Diff"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupNavigation()
        setupHeader()
        setupTable()
        setupEmpty()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Navigation

    private func setupNavigation() {
        let trashItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            trashItem = UIBarButtonItem(
                image: UIImage(systemName: "trash"),
                style: .plain, target: self, action: #selector(clearSnapshots))
        } else {
            trashItem = UIBarButtonItem(
                title: "Clear", style: .plain,
                target: self, action: #selector(clearSnapshots))
        }
        trashItem.tintColor = UIColor.Phantom.vibrantRed
        navigationItem.rightBarButtonItem = trashItem
    }

    // MARK: - Header card

    private func setupHeader() {
        headerCard.backgroundColor = PhantomTheme.shared.surfaceColor
        headerCard.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { headerCard.layer.cornerCurve = .continuous }
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerCard)

        // Before button
        let beforeBtn = makeSnapshotButton(
            title: "BEFORE", color: UIColor.Phantom.neonAzure,
            action: #selector(takeBefore))
        headerCard.addSubview(beforeBtn)
        beforeBtn.translatesAutoresizingMaskIntoConstraints = false

        // After button
        let afterBtn = makeSnapshotButton(
            title: "AFTER", color: UIColor.Phantom.vibrantOrange,
            action: #selector(takeAfter))
        headerCard.addSubview(afterBtn)
        afterBtn.translatesAutoresizingMaskIntoConstraints = false

        // Arrow icon
        if #available(iOS 13.0, *) {
            let cfg   = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            let arrow = UIImageView(image: UIImage(systemName: "arrow.right", withConfiguration: cfg))
            arrow.tintColor = UIColor.white.withAlphaComponent(0.25)
            arrow.translatesAutoresizingMaskIntoConstraints = false
            headerCard.addSubview(arrow)
            NSLayoutConstraint.activate([
                arrow.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
                arrow.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 22),
            ])
        }

        // Footprint labels beneath each button
        beforeLabel.font          = UIFont.phantomMonospaced(size: 12, weight: .semibold)
        beforeLabel.textColor     = UIColor.Phantom.neonAzure
        beforeLabel.textAlignment = .center
        beforeLabel.text          = "–"
        beforeLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(beforeLabel)

        afterLabel.font          = UIFont.phantomMonospaced(size: 12, weight: .semibold)
        afterLabel.textColor     = UIColor.Phantom.vibrantOrange
        afterLabel.textAlignment = .center
        afterLabel.text          = "–"
        afterLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(afterLabel)

        // Delta large label
        deltaLabel.font          = UIFont.phantomMonospaced(size: 24, weight: .bold)
        deltaLabel.textColor     = UIColor.white.withAlphaComponent(0.3)
        deltaLabel.textAlignment = .center
        deltaLabel.text          = "∆ —"
        deltaLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(deltaLabel)

        NSLayoutConstraint.activate([
            headerCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerCard.heightAnchor.constraint(equalToConstant: 116),

            beforeBtn.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 12),
            beforeBtn.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 12),
            beforeBtn.widthAnchor.constraint(equalTo: headerCard.widthAnchor, multiplier: 0.40),
            beforeBtn.heightAnchor.constraint(equalToConstant: 40),

            afterBtn.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -12),
            afterBtn.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 12),
            afterBtn.widthAnchor.constraint(equalTo: headerCard.widthAnchor, multiplier: 0.40),
            afterBtn.heightAnchor.constraint(equalToConstant: 40),

            beforeLabel.topAnchor.constraint(equalTo: beforeBtn.bottomAnchor, constant: 6),
            beforeLabel.leadingAnchor.constraint(equalTo: beforeBtn.leadingAnchor),
            beforeLabel.trailingAnchor.constraint(equalTo: beforeBtn.trailingAnchor),

            afterLabel.topAnchor.constraint(equalTo: afterBtn.bottomAnchor, constant: 6),
            afterLabel.leadingAnchor.constraint(equalTo: afterBtn.leadingAnchor),
            afterLabel.trailingAnchor.constraint(equalTo: afterBtn.trailingAnchor),

            deltaLabel.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            deltaLabel.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -12),
        ])
    }

    private func makeSnapshotButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .black)
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 10
        if #available(iOS 13.0, *) { btn.layer.cornerCurve = .continuous }
        btn.layer.borderWidth = 1
        btn.layer.borderColor = color.withAlphaComponent(0.35).cgColor
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Table

    private func setupTable() {
        tableView.backgroundColor     = .clear
        tableView.separatorStyle      = .none
        tableView.rowHeight           = UITableView.automaticDimension
        tableView.estimatedRowHeight  = 60
        tableView.dataSource          = self
        tableView.delegate            = self
        tableView.tableFooterView     = UIView()
        tableView.register(DiffObjectCell.self, forCellReuseIdentifier: DiffObjectCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Empty state

    private func setupEmpty() {
        emptyLabel.text          = "Tap BEFORE to baseline,\ninteract with your app,\nthen tap AFTER to see new allocations."
        emptyLabel.font          = .systemFont(ofSize: 14)
        emptyLabel.textColor     = UIColor.white.withAlphaComponent(0.3)
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
        ])
    }

    // MARK: - Actions

    @objc private func takeBefore() {
        PhantomMemorySlayer.shared.takeBeforeSnapshot()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        refresh()
    }

    @objc private func takeAfter() {
        PhantomMemorySlayer.shared.takeAfterSnapshot()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        refresh()
    }

    @objc private func clearSnapshots() {
        PhantomMemorySlayer.shared.clearSnapshots()
        refresh()
    }

    // MARK: - Data refresh

    private func refresh() {
        let slayer = PhantomMemorySlayer.shared
        let before = slayer.beforeSnapshot
        let after  = slayer.afterSnapshot

        beforeLabel.text = before.map { PhantomMemorySlayer.formatBytes($0.footprintBytes) } ?? "–"
        afterLabel.text  = after.map  { PhantomMemorySlayer.formatBytes($0.footprintBytes) } ?? "–"

        if let b = before, let a = after {
            let delta = a.footprintBytes - b.footprintBytes
            let sign  = delta >= 0 ? "+" : ""
            deltaLabel.text      = "\(sign)\(PhantomMemorySlayer.formatBytes(delta))"
            deltaLabel.textColor = delta > 0
                ? UIColor.Phantom.vibrantRed
                : UIColor.Phantom.vibrantGreen
        } else {
            deltaLabel.text      = "∆ —"
            deltaLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        }

        diffedObjects = slayer.diffedObjects()
        let showEmpty = before == nil || diffedObjects.isEmpty
        UIView.animate(withDuration: 0.2) {
            self.emptyLabel.alpha = showEmpty ? 1 : 0
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension MemoryDiffVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        diffedObjects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DiffObjectCell.reuseID, for: indexPath) as? DiffObjectCell else {
            return UITableViewCell()
        }
        cell.configure(with: diffedObjects[indexPath.row])
        return cell
    }

}

// MARK: - UITableViewDelegate

extension MemoryDiffVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !diffedObjects.isEmpty else { return nil }
        let label = UILabel()
        label.text      = "  NEW ALLOCATIONS (\(diffedObjects.count))"
        label.font      = .systemFont(ofSize: 10, weight: .black)
        label.textColor = UIColor.white.withAlphaComponent(0.35)
        label.backgroundColor = PhantomTheme.shared.backgroundColor
        return label
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        diffedObjects.isEmpty ? 0 : 28
    }
}

// MARK: - DiffObjectCell

private final class DiffObjectCell: UITableViewCell {
    static let reuseID = "DiffObjectCell"

    private let statusDot  = UIView()
    private let classLabel = UILabel()
    private let addrLabel  = UILabel()
    private let fileLabel  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none

        statusDot.layer.cornerRadius = 5
        statusDot.layer.masksToBounds = true
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusDot)

        classLabel.font      = UIFont.phantomMonospaced(size: 13, weight: .semibold)
        classLabel.textColor = UIColor.white
        classLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(classLabel)

        addrLabel.font      = UIFont.phantomMonospaced(size: 10, weight: .regular)
        addrLabel.textColor = UIColor.white.withAlphaComponent(0.38)
        addrLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addrLabel)

        fileLabel.font          = .systemFont(ofSize: 10)
        fileLabel.textColor     = UIColor.white.withAlphaComponent(0.38)
        fileLabel.textAlignment = .right
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileLabel)

        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        sep.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sep)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            classLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 10),
            classLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            classLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            addrLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            addrLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 2),
            addrLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            fileLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            fileLabel.centerYAnchor.constraint(equalTo: addrLabel.centerYAnchor),

            sep.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with obj: PhantomTrackedObject) {
        classLabel.text     = obj.className
        addrLabel.text      = obj.address
        fileLabel.text      = "\(obj.file):\(obj.line)"
        statusDot.backgroundColor = obj.isAlive
            ? UIColor.Phantom.vibrantGreen
            : UIColor.Phantom.vibrantRed.withAlphaComponent(0.5)
    }
}
#endif
