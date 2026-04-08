#if DEBUG
import UIKit

/// Niagara Launcher-style dashboard.
/// Alphabetical A→Z sections · right-side index scrubber · giant floating section letter.
internal final class PhantomDashboardVC: UIViewController {

    // MARK: - Item model

    private enum DashboardItem {
        case feature(PhantomFeature)
        case plugin(PhantomPlugin)

        var title: String {
            switch self {
            case .feature(let f):
                switch f {
                case .network:           return "Network"
                case .interceptor:       return "Interceptor"
                case .logger:            return "Logger"
                case .memoryLeak:        return "Leak Tracker"
                case .uiInspector:       return "UI Inspector"
                case .storage:           return "Storage"
                case .performance:       return "Performance"
                case .qa:                return "QA Shortcuts"
                case .security:          return "Security"
                case .swiftUI:           return "SwiftUI"
                case .accessibility:     return "Accessibility"
                case .environment:       return "Environment"
                case .extensionSidekick: return "Extensions"
                case .badNetwork:        return "Bad Network"
                case .hangDetector:      return "Hang Detector"
                case .stateSnapshot:     return "State Snapshot"
                case .analytics:         return "Analytics"
                case .memoryGraph:       return "Memory Graph"
                case .assetInspector:    return "Asset Inspector"
                case .featureFlags:      return "Feature Flags"
                case .mainThreadChecker: return "Thread Checker"
                case .waterfall:         return "Waterfall"
                case .remoteServer:      return "Remote Server"
                case .deepLinkTester:    return "Deep Link Tester"
                case .crashLogs:         return "Crash Logs"
                case .layoutConflicts:            return "Layout Conflicts"
                case .pushNotificationSimulator: return "Push Notifications"
                case .backgroundTaskInspector:  return "BG Tasks"
                case .runtimeBrowser:           return "Runtime Browser"
                }
            case .plugin(let p): return p.title
            }
        }

        var icon: String {
            switch self {
            case .feature(let f):
                switch f {
                case .network:           return "network"
                case .interceptor:       return "bolt.shield"
                case .logger:            return "terminal"
                case .memoryLeak:        return "drop.triangle"
                case .uiInspector:       return "view.3d"
                case .storage:           return "archivebox"
                case .performance:       return "gauge.medium"
                case .qa:                return "ant"
                case .security:          return "lock.shield"
                case .swiftUI:           return "atom"
                case .accessibility:     return "figure.roll"
                case .environment:       return "globe"
                case .extensionSidekick: return "puzzlepiece"
                case .badNetwork:        return "wifi.exclamationmark"
                case .hangDetector:      return "hand.raised.slash"
                case .stateSnapshot:     return "clock.arrow.2.circlepath"
                case .analytics:         return "chart.bar.doc.horizontal"
                case .memoryGraph:       return "brain.head.profile"
                case .assetInspector:    return "photo.on.rectangle"
                case .featureFlags:      return "flag.fill"
                case .mainThreadChecker: return "exclamationmark.triangle.fill"
                case .waterfall:         return "chart.bar.xaxis"
                case .remoteServer:      return "antenna.radiowaves.left.and.right"
                case .deepLinkTester:    return "link.badge.plus"
                case .crashLogs:         return "exclamationmark.octagon.fill"
                case .layoutConflicts:            return "ruler"
                case .pushNotificationSimulator: return "bell.badge"
                case .backgroundTaskInspector:  return "gearshape.2"
                case .runtimeBrowser:           return "cpu"
                }
            case .plugin(let p): return p.icon
            }
        }

        var accent: UIColor {
            switch self {
            case .plugin: return UIColor.Phantom.electricIndigo
            case .feature(let f):
                switch f {
                case .network, .interceptor, .badNetwork:     return UIColor.Phantom.neonAzure
                case .logger:                                  return UIColor.Phantom.vibrantGreen
                case .performance, .hangDetector:              return UIColor.Phantom.vibrantOrange
                case .memoryLeak, .memoryGraph:               return UIColor.Phantom.vibrantRed
                case .uiInspector, .swiftUI, .assetInspector,
                     .accessibility:                           return UIColor.Phantom.vibrantPurple
                case .featureFlags:                            return UIColor.Phantom.vibrantOrange
                case .mainThreadChecker:                       return UIColor.Phantom.vibrantRed
                case .waterfall:                               return UIColor.Phantom.neonAzure
                case .remoteServer:                            return UIColor.Phantom.vibrantGreen
                case .deepLinkTester:                          return UIColor.Phantom.neonAzure
                case .crashLogs:                               return UIColor.Phantom.vibrantRed
                case .layoutConflicts:                         return UIColor.Phantom.vibrantOrange
                case .pushNotificationSimulator:               return UIColor.Phantom.vibrantPurple
                case .backgroundTaskInspector:                 return UIColor.Phantom.vibrantOrange
                case .runtimeBrowser:                          return UIColor.Phantom.vibrantGreen
                default:                                       return UIColor.Phantom.electricIndigo
                }
            }
        }

        /// Live count shown as a badge on the cell — 0 means no badge.
        var badge: Int {
            switch self {
            case .feature(let f):
                switch f {
                case .logger:     return LogStore.shared.getAll().count
                case .network,
                     .interceptor: return PhantomRequestStore.shared.getAll().count
                case .featureFlags: return PhantomFeatureFlags.shared.overrideCount
                case .mainThreadChecker: return PhantomMainThreadChecker.shared.violationCount
                case .crashLogs:                 return PhantomCrashLogStore.shared.count
                case .layoutConflicts:           return PhantomLayoutConflictDetector.shared.count
                case .backgroundTaskInspector:
                    if #available(iOS 13.0, *) { return PhantomBGTaskInspector.shared.pendingCount }
                    return 0
                default:          return 0
                }
            case .plugin:         return 0
            }
        }
    }

    // MARK: - Alphabetical section model

    private struct AlphaSection {
        let letter: String
        let items: [DashboardItem]
    }

    // MARK: - UI properties

    /// Giant floating letter — Niagara's centrepiece scroll indicator.
    private let currentLetterLabel = UILabel()
    private let tableView          = UITableView(frame: .zero, style: .plain)
    private let headerView         = UIView()
    private let dragHandle         = UIView()
    private let wordmarkLabel      = UILabel()
    private let envLabel           = UILabel()
    private let closeButton        = UIButton(type: .system)
    private let scrubber           = AlphaScrubberView()

    private var sections: [AlphaSection] = []
    private var lastVisibleSection = -1
    private let emptyStateView = PhantomEmptyStateView(
        emoji: "🔍",
        title: "No Results",
        message: "No modules match your search."
    )

    // MARK: - Search state
    private let searchBar   = UISearchBar()
    private var filterText   = ""
    private var panInitialY: CGFloat = 0

    // MARK: - Recents
    private let recentsKey      = "com.phantom.recentModules"
    private var recentTitles: [String] = []
    private var hasAppeared = false
    private var displaySections: [AlphaSection] {
        if filterText.isEmpty {
            // Alphabetical list, optionally prefixed with Recents
            let recentItems = recentTitles.compactMap { title in
                sections.flatMap { $0.items }.first { $0.title == title }
            }
            var result = sections
            if !recentItems.isEmpty {
                result.insert(AlphaSection(letter: "★", items: recentItems), at: 0)
            }
            return result
        }
        // Filtered A–Z (no recents)
        let q = filterText.lowercased()
        return sections.compactMap { sec in
            let matches = sec.items.filter { $0.title.lowercased().contains(q) }
            return matches.isEmpty ? nil : AlphaSection(letter: sec.letter, items: matches)
        }
    }

    // MARK: - Init

    internal init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSections()
        setupFrostedBackground()
        setupHeader()
        setupSearch()
        setupTable()
        setupSwipeToDismiss()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Re-sync table to current recentTitles after returning from a module.
        // Without this, the ★ recents section is stale: its displayed rows no
        // longer match the recentTitles array that didSelectRowAt reads from
        // displaySections, causing the wrong module to open.
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAppeared else { return }
        hasAppeared = true
        animateIn()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Frosted glass background

    private func setupFrostedBackground() {
        // Deep dark base (fallback for iOS 12)
        view.backgroundColor = UIColor(white: 0.04, alpha: 1.0)

        if #available(iOS 13.0, *) {
            // Subtle blur overlay — dashboard floats like a sheet
            let blur = UIBlurEffect(style: .systemChromeMaterialDark)
            let blurView = UIVisualEffectView(effect: blur)
            blurView.frame = view.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.alpha = 0.55
            view.insertSubview(blurView, at: 0)
        }
    }

    // MARK: - Build alphabetical sections

    private func buildSections() {
        let enabled = Set(PhantomSwift.shared.config.environment.enabledFeatures)

        var all: [DashboardItem] = PhantomFeature.allCases
            .filter { enabled.contains($0) }
            .map   { .feature($0) }
        all += PhantomSwift.shared.registeredPlugins.map { .plugin($0) }

        let sorted = all.sorted { $0.title < $1.title }
        var grouped: [String: [DashboardItem]] = [:]
        for item in sorted {
            let key = String(item.title.prefix(1)).uppercased()
            grouped[key, default: []].append(item)
        }
        sections = grouped.keys.sorted().compactMap { letter in
            grouped[letter].map { AlphaSection(letter: letter, items: $0) }
        }
        // Scrubber always shows A–Z (not ★ — recents are always at the top)
        scrubber.letters = sections.map { $0.letter }
        // Load persisted recents
        recentTitles = (UserDefaults.standard.array(forKey: recentsKey) as? [String]) ?? []
    }

    // MARK: - Header

    private func setupHeader() {
        setupDragHandle()
        setupHeaderView()
        setupCurrentLetterLabel()
        setupWordmarkLabel()
        setupEnvLabel()
        setupCloseButton()
        setupHeaderConstraints()
    }

    private func setupDragHandle() {
        dragHandle.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        dragHandle.layer.cornerRadius = 2.5
        view.addSubview(dragHandle)
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupHeaderView() {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
    }

    private func setupCurrentLetterLabel() {
        currentLetterLabel.font = UIFont.systemFont(ofSize: 96, weight: .black)
        currentLetterLabel.textColor = UIColor.white.withAlphaComponent(0.08)
        currentLetterLabel.text = sections.first?.letter ?? ""
        headerView.addSubview(currentLetterLabel)
        currentLetterLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupWordmarkLabel() {
        wordmarkLabel.text = "PhantomSwift"
        wordmarkLabel.font = UIFont.systemFont(ofSize: 22, weight: .black)
        wordmarkLabel.textColor = .white
        headerView.addSubview(wordmarkLabel)
        wordmarkLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupEnvLabel() {
        let env = PhantomSwift.shared.config.environment.name.lowercased()
        envLabel.text = " \(env) "
        envLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        envLabel.textColor = .white
        envLabel.backgroundColor = UIColor.Phantom.electricIndigo
        envLabel.textAlignment = .center
        envLabel.layer.cornerRadius = 8
        envLabel.clipsToBounds = true
        headerView.addSubview(envLabel)
        envLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupCloseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let xIcon = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        closeButton.setImage(xIcon, for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.3)
        closeButton.addTarget(self, action: #selector(dismissDashboard), for: .touchUpInside)
        headerView.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupHeaderConstraints() {
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 40),
            dragHandle.heightAnchor.constraint(equalToConstant: 5),

            headerView.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),

            currentLetterLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: 20),
            currentLetterLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),

            wordmarkLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            wordmarkLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),

            envLabel.leadingAnchor.constraint(equalTo: wordmarkLabel.trailingAnchor, constant: 12),
            envLabel.centerYAnchor.constraint(equalTo: wordmarkLabel.centerYAnchor),
            envLabel.heightAnchor.constraint(equalToConstant: 16),
            envLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Search bar

    private func setupSearch() {
        searchBar.placeholder      = "Search modules…"
        searchBar.searchBarStyle   = .minimal
        searchBar.barStyle         = .black
        searchBar.tintColor        = UIColor.Phantom.electricIndigo
        searchBar.delegate         = self
        searchBar.backgroundColor  = .clear

        if #available(iOS 13.0, *) {
            let tf = searchBar.searchTextField
            tf.backgroundColor = UIColor.white.withAlphaComponent(0.10)
            tf.textColor       = .white
            tf.tintColor       = UIColor.Phantom.electricIndigo
            tf.attributedPlaceholder = NSAttributedString(
                string: "Search modules…",
                attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.35)]
            )
            if let glassIcon = tf.leftView as? UIImageView {
                glassIcon.tintColor = UIColor.white.withAlphaComponent(0.35)
            }
        }

        view.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Table

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 76
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(NiagaraModuleCell.self, forCellReuseIdentifier: NiagaraModuleCell.reuseID)
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 48))
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Custom scrubber overlaid on right edge
        scrubber.onLetterChanged = { [weak self] index in
            guard let self, index < self.sections.count else { return }
            let letter = self.sections[index].letter
            // Find the matching section in displaySections (★ may be at index 0)
            guard let dsIdx = self.displaySections.firstIndex(where: { $0.letter == letter }) else { return }
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: dsIdx), at: .top, animated: false)
            UIView.transition(with: self.currentLetterLabel, duration: 0.18, options: .transitionCrossDissolve) {
                self.currentLetterLabel.text = letter
            }
        }
        view.addSubview(scrubber)
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrubber.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            scrubber.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            scrubber.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrubber.widthAnchor.constraint(equalToConstant: 28),
        ])
    }

    // MARK: - Swipe to dismiss

    private func setupSwipeToDismiss() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func handleDismissPan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity    = pan.velocity(in: view)

        switch pan.state {
        case .began:
            panInitialY = view.frame.origin.y

        case .changed:
            let dy = max(0, translation.y)
            view.frame.origin.y = panInitialY + dy

        case .ended, .cancelled:
            let shouldDismiss = translation.y > 180 || velocity.y > 650
            if shouldDismiss {
                UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseIn) {
                    self.view.frame.origin.y = UIScreen.main.bounds.height
                } completion: { _ in
                    self.dismiss(animated: false)
                    PhantomEventBus.shared.post(.dashboardDismissed)
                }
            } else {
                UIView.animate(
                    withDuration: 0.52, delay: 0,
                    usingSpringWithDamping: 0.72, initialSpringVelocity: 0.3,
                    options: .beginFromCurrentState
                ) {
                    self.view.frame.origin.y = self.panInitialY
                }
            }

        default: break
        }
    }

    // MARK: - Entrance animation

    private func animateIn() {
        for (i, cell) in tableView.visibleCells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 40)
            UIView.animate(
                withDuration: 0.46,
                delay: 0.025 * Double(i),
                usingSpringWithDamping: 0.80,
                initialSpringVelocity: 0.2,
                options: .curveEaseOut
            ) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }

    // MARK: - Actions

    @objc private func dismissDashboard() {
        dismiss(animated: true)
        PhantomEventBus.shared.post(.dashboardDismissed)
    }

    @objc private func dismissModule() { dismiss(animated: true) }
}

// MARK: - UITableViewDataSource & Delegate

extension PhantomDashboardVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { displaySections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displaySections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NiagaraModuleCell.reuseID, for: indexPath) as? NiagaraModuleCell else {
            return UITableViewCell()
        }
        let item = displaySections[indexPath.section].items[indexPath.row]
        cell.configure(title: item.title, icon: item.icon, accent: item.accent, badge: item.badge)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < displaySections.count else { return nil }
        let letter = displaySections[section].letter

        let container = UIView()
        container.backgroundColor = .clear

        let label = UILabel()
        label.text      = letter
        label.font      = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor.white.withAlphaComponent(0.35)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 28
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? { nil }
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        index
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard filterText.isEmpty else { return }
        guard let firstPath = tableView.indexPathsForVisibleRows?.first else { return }
        let sec = firstPath.section
        guard sec != lastVisibleSection, sec < displaySections.count else { return }
        lastVisibleSection = sec
        UIView.transition(with: currentLetterLabel, duration: 0.18, options: .transitionCrossDissolve) {
            self.currentLetterLabel.text = self.displaySections[sec].letter
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openModule(displaySections[indexPath.section].items[indexPath.row])
    }

    // MARK: Context Menu (iOS 13+)

    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section < displaySections.count,
              indexPath.row < displaySections[indexPath.section].items.count else { return nil }
        let item = displaySections[indexPath.section].items[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu(title: "", children: []) }

            let openAction = UIAction(
                title: "Open",
                image: UIImage(systemName: "arrow.right.circle")
            ) { [weak self] _ in
                self?.openModule(item)
            }

            let copyAction = UIAction(
                title: "Copy Name",
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                UIPasteboard.general.string = item.title
            }

            let isRecent = self.recentTitles.contains(item.title)
            let removeAction = UIAction(
                title: "Remove from Recents",
                image: UIImage(systemName: "clock.badge.xmark"),
                attributes: isRecent ? [] : .disabled
            ) { [weak self] _ in
                guard let self else { return }
                self.recentTitles.removeAll { $0 == item.title }
                UserDefaults.standard.set(self.recentTitles, forKey: self.recentsKey)
                self.tableView.reloadData()
            }

            return UIMenu(title: item.title, children: [openAction, copyAction, removeAction])
        }
    }

    private func openModule(_ item: DashboardItem) {
        recordRecent(item)
        if case .feature(.uiInspector) = item {
            dismiss(animated: true) { PhantomUIInspector.shared.startInspecting() }
            return
        }
        let vc = makeVC(for: item)
        let nav = UINavigationController(rootViewController: vc)
        styleNav(nav, backTarget: vc)
        present(nav, animated: true)
    }

    private func recordRecent(_ item: DashboardItem) {
        var titles = recentTitles.filter { $0 != item.title }
        titles.insert(item.title, at: 0)
        recentTitles = Array(titles.prefix(3))
        UserDefaults.standard.set(recentTitles, forKey: recentsKey)
    }

    private func makeVC(for item: DashboardItem) -> UIViewController {
        switch item {
        case .feature(let f):
            return makeVC(forFeature: f)
        case .plugin(let p):
            let nc = UINavigationController(rootViewController: p.viewController)
            nc.phantomApplyNavBarAppearance()
            return nc
        }
    }

    private func makeVC(forFeature f: PhantomFeature) -> UIViewController {
        switch f {
        case .network:           return PhantomNav(rootViewController: NetworkListVC())
        case .interceptor:       return PhantomNav(rootViewController: InterceptorListVC())
        case .logger:            return PhantomNav(rootViewController: LogConsoleVC())
        case .memoryLeak:        return PhantomNav(rootViewController: LeakListVC())
        case .uiInspector:       return PhantomNav(rootViewController: PhantomUIInspector())
        case .storage:           return PhantomNav(rootViewController: StorageDashboardVC())
        case .performance:       return PhantomNav(rootViewController: PerformanceDashboardVC())
        case .qa:                return PhantomNav(rootViewController: QAShortcutsVC())
        case .security:          return PhantomNav(rootViewController: SecurityDashboardVC())
        case .swiftUI:           return PhantomNav(rootViewController: SwiftUIInspectorVC())
        case .accessibility:     return PhantomNav(rootViewController: AccessibilityAuditVC())
        case .environment:       return PhantomNav(rootViewController: EnvironmentDashboardVC())
        case .extensionSidekick: return PhantomNav(rootViewController: ExtensionSidekickVC())
        case .badNetwork:        return PhantomNav(rootViewController: BadNetworkVC())
        case .hangDetector:      return PhantomNav(rootViewController: HangListVC())
        case .stateSnapshot:     return PhantomNav(rootViewController: StateSnapshotVC())
        case .analytics:         return PhantomNav(rootViewController: AnalyticsListVC())
        case .memoryGraph:       return PhantomNav(rootViewController: ObjectRetainGraphVC())
        case .assetInspector:    return PhantomNav(rootViewController: AssetInspectorVC())
        case .featureFlags:      return PhantomNav(rootViewController: FeatureFlagsDashboardVC())
        case .mainThreadChecker: return PhantomNav(rootViewController: MainThreadCheckerVC())
        case .waterfall:         return PhantomNav(rootViewController: NetworkWaterfallVC())
        case .remoteServer:      return PhantomNav(rootViewController: RemoteServerVC())
        case .deepLinkTester:    return PhantomNav(rootViewController: DeepLinkTesterVC())
        case .crashLogs:         return PhantomNav(rootViewController: CrashLogVC())
        case .layoutConflicts:   return PhantomNav(rootViewController: LayoutConflictVC())
        case .pushNotificationSimulator: return PhantomNav(rootViewController: PushSimulatorVC())
        case .backgroundTaskInspector:   return PhantomNav(rootViewController: BGTaskInspectorVC())
        case .runtimeBrowser:    return PhantomNav(rootViewController: RuntimeBrowserVC())
        }
    }

    private func styleNav(_ nav: UINavigationController, backTarget vc: UIViewController) {
        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()
            a.backgroundColor = UIColor(white: 0.06, alpha: 1)
            a.titleTextAttributes = [.foregroundColor: UIColor.white]
            nav.navigationBar.standardAppearance = a
            nav.navigationBar.scrollEdgeAppearance = a
        }
        nav.navigationBar.tintColor = UIColor.Phantom.electricIndigo
        nav.modalPresentationStyle = .fullScreen
        if #available(iOS 13.0, *) {
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"), style: .plain,
                target: self, action: #selector(dismissModule))
        } else {
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Back", style: .plain,
                target: self, action: #selector(dismissModule))
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PhantomDashboardVC: UIGestureRecognizerDelegate {
    /// Only intercept downward pans when the table is at the very top.
    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let pan = gr as? UIPanGestureRecognizer else { return true }
        let vel = pan.velocity(in: view)
        return vel.y > 0 && tableView.contentOffset.y <= 0
    }
    /// Allow the dismiss pan and the table's scroll recognizer to coexist.
    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - UISearchBarDelegate

extension PhantomDashboardVC: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterText = searchText
        lastVisibleSection = -1
        tableView.reloadData()

        let searching = !searchText.isEmpty
        let noResults = searching && displaySections.isEmpty
        scrubber.isHidden = searching

        UIView.animate(withDuration: 0.20) {
            self.emptyStateView.isHidden = !noResults
            self.tableView.alpha = noResults ? 0 : 1
        }
        UIView.transition(with: currentLetterLabel, duration: 0.18,
                          options: .transitionCrossDissolve) {
            self.currentLetterLabel.text = searching
                ? ""
                : (self.sections.first?.letter ?? "")
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        filterText = ""
        lastVisibleSection = -1
        tableView.reloadData()
        scrubber.isHidden = false
        emptyStateView.isHidden = true
        tableView.alpha = 1
        UIView.transition(with: currentLetterLabel, duration: 0.18,
                          options: .transitionCrossDissolve) {
            self.currentLetterLabel.text = self.sections.first?.letter ?? ""
        }
    }
}

// MARK: - NiagaraModuleCell

// MARK: - AlphaScrubberView
/// Custom A–Z index scrubber — Niagara style.
///
/// Interaction model:
///   • Hold 80 ms on the pill   → activates (track brightens, haptic fires)
///   • Drag while holding       → letter scales up 1.45× + turns white, haptic per step
///   • Release                  → letters and track return to rest
///
/// No floating bubble. No colored circles. Purely typographic.
private final class AlphaScrubberView: UIView {

    // MARK: Public API
    var letters: [String] = [] { didSet { buildLetterViews() } }
    var onLetterChanged: ((Int) -> Void)?

    // MARK: Sub-views
    private let trackView    = UIView()
    private var letterLabels: [UILabel] = []

    // MARK: Layout constants
    private let letterH: CGFloat = 22
    private let trackW:  CGFloat = 20

    // MARK: State
    private var currentIndex = -1

    // MARK: Haptics
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback    = UIImpactFeedbackGenerator(style: .medium)

    // MARK: Init
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup
    private func setup() {
        backgroundColor = .clear
        clipsToBounds = false

        // ── Pill track ──────────────────────────────────────────────────────
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        trackView.layer.cornerRadius = trackW / 2
        if #available(iOS 13.0, *) { trackView.layer.cornerCurve = .continuous }
        addSubview(trackView)

        // ── Gesture ─────────────────────────────────────────────────────────
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        lp.minimumPressDuration  = 0.08
        lp.allowableMovement     = .greatestFiniteMagnitude  // never cancels on drag
        lp.cancelsTouchesInView  = false                     // table scroll passes through
        addGestureRecognizer(lp)

        selectionFeedback.prepare()
        impactFeedback.prepare()
    }

    // MARK: Letter views
    private func buildLetterViews() {
        letterLabels.forEach { $0.removeFromSuperview() }
        letterLabels = letters.map { letter in
            let lbl = UILabel()
            lbl.text          = letter
            lbl.font          = UIFont.systemFont(ofSize: 11, weight: .semibold)
            lbl.textColor     = UIColor.white.withAlphaComponent(0.55)
            lbl.textAlignment = .center
            addSubview(lbl)
            return lbl
        }
        currentIndex = -1
        setNeedsLayout()
    }

    // MARK: Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !letters.isEmpty else { return }

        let totalH  = CGFloat(letters.count) * letterH
        let startY  = max(0, (bounds.height - totalH) / 2)
        let centerX = bounds.width / 2

        trackView.frame = CGRect(
            x: centerX - trackW / 2, y: startY - 8,
            width: trackW, height: totalH + 16
        )

        for (i, lbl) in letterLabels.enumerated() {
            lbl.frame = CGRect(x: 0, y: startY + CGFloat(i) * letterH,
                               width: bounds.width, height: letterH)
        }
    }

    // MARK: Gesture handler
    @objc private func handleGesture(_ gr: UILongPressGestureRecognizer) {
        switch gr.state {
        case .began:
            impactFeedback.impactOccurred()
            setActive(true)
            updateSelection(indexForY(gr.location(in: self).y))
        case .changed:
            updateSelection(indexForY(gr.location(in: self).y))
        case .ended, .cancelled, .failed:
            setActive(false)
        default:
            break
        }
    }

    // MARK: Activate / deactivate track
    private func setActive(_ active: Bool) {
        UIView.animate(
            withDuration: active ? 0.22 : 0.30,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.4,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.trackView.backgroundColor = active
                ? UIColor.white.withAlphaComponent(0.18)
                : UIColor.white.withAlphaComponent(0.08)
            self.trackView.transform = active
                ? CGAffineTransform(scaleX: 1.12, y: 1.0)
                : .identity
        }

        if !active {
            // Reset all letter labels
            currentIndex = -1
            UIView.animate(withDuration: 0.20, delay: 0.05,
                           options: [.curveEaseOut, .beginFromCurrentState]) {
                self.letterLabels.forEach {
                    $0.transform = .identity
                    $0.textColor = UIColor.white.withAlphaComponent(0.55)
                }
            }
        }
    }

    // MARK: Index calculation
    private func indexForY(_ y: CGFloat) -> Int {
        let totalH = CGFloat(letters.count) * letterH
        let startY = max(0, (bounds.height - totalH) / 2)
        let raw    = Int((y - startY) / letterH)
        return min(max(raw, 0), letters.count - 1)
    }

    // MARK: Selection update
    private func updateSelection(_ idx: Int) {
        guard idx >= 0, idx < letters.count, idx != currentIndex else { return }
        let prev = currentIndex
        currentIndex = idx

        selectionFeedback.selectionChanged()
        onLetterChanged?(idx)

        // ── Prev letter → rest ───────────────────────────────────────────────
        if prev >= 0, prev < letterLabels.count {
            UIView.animate(withDuration: 0.18, delay: 0,
                           options: [.curveEaseOut, .beginFromCurrentState]) {
                self.letterLabels[prev].transform = .identity
                self.letterLabels[prev].textColor = UIColor.white.withAlphaComponent(0.55)
            }
        }

        // ── Active letter → pop 1 → 1.45 → 1.15 ────────────────────────────
        guard idx < letterLabels.count else { return }
        UIView.animateKeyframes(
            withDuration: 0.30, delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0,    relativeDuration: 0.35) {
                self.letterLabels[idx].transform = CGAffineTransform(scaleX: 1.45, y: 1.45)
                self.letterLabels[idx].textColor = .white
            }
            UIView.addKeyframe(withRelativeStartTime: 0.35, relativeDuration: 0.65) {
                self.letterLabels[idx].transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
        }
    }
}

#endif
