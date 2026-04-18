#if DEBUG
import UIKit
import PhantomSwiftNetworking

// MARK: - MockoonCardView

private final class MockoonCardView: UIView, UITextFieldDelegate {
    var onConfigChange: ((MockoonConfig) -> Void)?
    private var config: MockoonConfig = PhantomInterceptor.shared.mockoonConfig

    private let statusDot       = UIView()
    private let titleLabel      = UILabel()
    private let subtitleLabel   = UILabel()
    private let toggleSwitch    = UISwitch()
    private let divider1        = UIView()
    private let hostLabel       = UILabel()
    private let portLabel       = UILabel()
    private let hostField       = UITextField()
    private let portField       = UITextField()
    private let divider2        = UIView()
    private let excludeLabel    = UILabel()
    private let excludeField    = UITextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        setupAppearance()
        setupSubviews()
        setupConstraints()
        updateAppearance()
    }

    private func setupAppearance() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
    }

    private func setupSubviews() {
        // Status dot
        statusDot.layer.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusDot)

        // Title
        titleLabel.text = "Mockoon Server"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Toggle
        toggleSwitch.onTintColor = PhantomTheme.shared.primaryColor
        toggleSwitch.isOn = config.isEnabled
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toggleSwitch)

        // Subtitle
        subtitleLabel.text = "Redirect all traffic to local mock server"
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // Divider 1
        divider1.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider1.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider1)

        // Host / Port
        hostLabel.text = "HOST"
        styleInputLabel(hostLabel)
        portLabel.text = "PORT"
        styleInputLabel(portLabel)

        styleTextField(hostField, placeholder: "localhost", text: config.host)
        hostField.autocorrectionType = .no
        hostField.autocapitalizationType = .none
        hostField.delegate = self

        styleTextField(portField, placeholder: "3000", text: "\(config.port)")
        portField.keyboardType = .numberPad
        portField.delegate = self

        // Divider 2
        divider2.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider2.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider2)

        // Exclude patterns
        excludeLabel.text = "SKIP PATTERNS"
        styleInputLabel(excludeLabel)

        styleTextField(excludeField,
                       placeholder: "e.g. *.analytics.com, */cdn/*",
                       text: config.excludePatterns.joined(separator: ", "))
        excludeField.autocorrectionType = .no
        excludeField.autocapitalizationType = .none
        excludeField.delegate = self
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title row
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8),

            toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8),

            // Divider 1
            divider1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider1.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            divider1.heightAnchor.constraint(equalToConstant: 1),

            // Host/Port row labels
            hostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hostLabel.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 10),

            portLabel.leadingAnchor.constraint(equalTo: portField.leadingAnchor),
            portLabel.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 10),

            // Host/Port fields
            hostField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hostField.topAnchor.constraint(equalTo: hostLabel.bottomAnchor, constant: 4),
            hostField.trailingAnchor.constraint(equalTo: portField.leadingAnchor, constant: -12),
            hostField.heightAnchor.constraint(equalToConstant: 40),

            portField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            portField.topAnchor.constraint(equalTo: portLabel.bottomAnchor, constant: 4),
            portField.widthAnchor.constraint(equalToConstant: 88),
            portField.heightAnchor.constraint(equalToConstant: 40),

            // Divider 2
            divider2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider2.topAnchor.constraint(equalTo: hostField.bottomAnchor, constant: 14),
            divider2.heightAnchor.constraint(equalToConstant: 1),

            // Exclude patterns
            excludeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            excludeLabel.topAnchor.constraint(equalTo: divider2.bottomAnchor, constant: 10),

            excludeField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            excludeField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            excludeField.topAnchor.constraint(equalTo: excludeLabel.bottomAnchor, constant: 4),
            excludeField.heightAnchor.constraint(equalToConstant: 40),
            excludeField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    private func styleInputLabel(_ label: UILabel) {
        label.font = .systemFont(ofSize: 9, weight: .black)
        label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
    }

    private func styleTextField(_ tf: UITextField, placeholder: String, text: String) {
        tf.placeholder = placeholder
        tf.text = text
        tf.backgroundColor = PhantomTheme.shared.backgroundColor
        tf.textColor = PhantomTheme.shared.textColor
        if #available(iOS 13.0, *) {
            tf.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        } else {
            tf.font = UIFont(name: "Menlo", size: 13)
        }
        tf.layer.cornerRadius = 8
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        tf.leftViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tf)
    }

    private func updateAppearance() {
        let isActive = config.isEnabled
        statusDot.backgroundColor = isActive ? .systemGreen : .systemGray
        hostField.alpha = isActive ? 1.0 : 0.45
        portField.alpha = isActive ? 1.0 : 0.45
        excludeField.alpha = isActive ? 1.0 : 0.45
        hostField.isUserInteractionEnabled = isActive
        portField.isUserInteractionEnabled = isActive
        excludeField.isUserInteractionEnabled = isActive
        layer.borderColor = isActive
            ? PhantomTheme.shared.primaryColor.withAlphaComponent(0.3).cgColor
            : UIColor.white.withAlphaComponent(0.08).cgColor
    }

    @objc private func toggleChanged() {
        config.isEnabled = toggleSwitch.isOn
        applyChanges()
    }

    private func applyChanges() {
        updateAppearance()
        onConfigChange?(config)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === hostField {
            let raw = hostField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            config.host = raw.isEmpty ? "localhost" : raw
            hostField.text = config.host
        } else if textField === portField {
            config.port = Int(portField.text ?? "") ?? 3000
            portField.text = "\(config.port)"
        } else if textField === excludeField {
            let raw = excludeField.text ?? ""
            config.excludePatterns = raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        applyChanges()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func refresh() {
        config = PhantomInterceptor.shared.mockoonConfig
        toggleSwitch.isOn = config.isEnabled
        hostField.text = config.host
        portField.text = "\(config.port)"
        excludeField.text = config.excludePatterns.joined(separator: ", ")
        updateAppearance()
    }
}

private final class PaddingLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}

// MARK: - InterceptorListVC

/// Displays a modern, grid-based list of active interception rules.
internal final class InterceptorListVC: UIViewController {
    private var collectionView: UICollectionView
    private var rules: [PhantomInterceptRule] = []
    private let mockoonCard = MockoonCardView()
    private let overviewCard = UIView()
    private let activityCard = UIView()
    private let activityStack = UIStackView()
    private let activityEmptyLabel = UILabel()
    private let totalValueLabel = UILabel()
    private let activeValueLabel = UILabel()
    private let hitsValueLabel = UILabel()
    private let mockoonValueLabel = UILabel()
    private var refreshTimer: Timer?
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 90)
        layout.minimumLineSpacing = 0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mockoonCard.refresh()
        loadRules()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLiveRefresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopLiveRefresh()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "INTERCEPTOR"

        // Mockoon redirect card
        mockoonCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mockoonCard)
        mockoonCard.onConfigChange = { config in
            PhantomInterceptor.shared.updateMockoon(config)
        }

        setupOverviewCard()
        setupActivityCard()

        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(InterceptorCardCell.self, forCellWithReuseIdentifier: "RuleCell")
        view.addSubview(collectionView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mockoonCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mockoonCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mockoonCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            overviewCard.topAnchor.constraint(equalTo: mockoonCard.bottomAnchor, constant: 12),
            overviewCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            overviewCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            activityCard.topAnchor.constraint(equalTo: overviewCard.bottomAnchor, constant: 12),
            activityCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            activityCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: activityCard.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupOverviewCard() {
        overviewCard.backgroundColor = PhantomTheme.shared.surfaceColor
        overviewCard.layer.cornerRadius = 18
        overviewCard.layer.borderWidth = 1
        overviewCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        overviewCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overviewCard)

        let titleLabel = UILabel()
        titleLabel.text = "Runtime Overview"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Observe rule coverage, live activation, and traffic impact."
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.48)
        subtitleLabel.numberOfLines = 2

        let grid = UIStackView()
        grid.axis = .horizontal
        grid.distribution = .fillEqually
        grid.spacing = 10
        [
            metricTile(title: "Rules", valueLabel: totalValueLabel, accent: UIColor.Phantom.neonAzure),
            metricTile(title: "Active", valueLabel: activeValueLabel, accent: UIColor.Phantom.vibrantGreen),
            metricTile(title: "Hits", valueLabel: hitsValueLabel, accent: UIColor.Phantom.vibrantOrange),
            metricTile(title: "Mockoon", valueLabel: mockoonValueLabel, accent: UIColor.Phantom.vibrantPurple)
        ].forEach { grid.addArrangedSubview($0) }

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, grid])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        overviewCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: overviewCard.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: overviewCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: overviewCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: overviewCard.bottomAnchor, constant: -16)
        ])
    }

    private func setupActivityCard() {
        activityCard.backgroundColor = PhantomTheme.shared.surfaceColor
        activityCard.layer.cornerRadius = 18
        activityCard.layer.borderWidth = 1
        activityCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        activityCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityCard)

        let titleLabel = UILabel()
        titleLabel.text = "Recent Rule Activity"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Live feed of the latest interceptor matches in this session."
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.48)
        subtitleLabel.numberOfLines = 2

        activityStack.axis = .vertical
        activityStack.spacing = 10

        activityEmptyLabel.text = "No rule matches yet. Trigger traffic to verify your rules."
        activityEmptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        activityEmptyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.52)
        activityEmptyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, activityStack])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        activityCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: activityCard.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: activityCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: activityCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: activityCard.bottomAnchor, constant: -16)
        ])
    }

    private func metricTile(title: String, valueLabel: UILabel, accent: UIColor) -> UIView {
        let tile = UIView()
        tile.backgroundColor = accent.withAlphaComponent(0.08)
        tile.layer.cornerRadius = 14
        tile.layer.borderWidth = 1
        tile.layer.borderColor = accent.withAlphaComponent(0.12).cgColor

        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 9, weight: .black)
        titleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.45)
        titleLabel.textAlignment = .center

        valueLabel.font = UIFont.phantomMonospaced(size: 14, weight: .bold)
        valueLabel.textColor = accent
        valueLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(stack)

        NSLayoutConstraint.activate([
            tile.heightAnchor.constraint(equalToConstant: 64),
            stack.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: tile.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: tile.trailingAnchor, constant: -6)
        ])

        return tile
    }
    
    private func setupNavigation() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"), style: .plain, target: self, action: #selector(addNewRule))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewRule))
        }
    }
    
    private func loadRules() {
        self.rules = PhantomInterceptor.shared.getAll().sorted(by: { $0.createdAt > $1.createdAt })
        let snapshot = PhantomInterceptor.shared.snapshot()
        totalValueLabel.text = "\(snapshot.totalRules)"
        activeValueLabel.text = "\(snapshot.enabledRules)"
        hitsValueLabel.text = "\(snapshot.totalHits)"
        mockoonValueLabel.text = snapshot.mockoonEnabled ? "ON" : "OFF"
        refreshRecentActivity()
        self.collectionView.reloadData()
        
        if rules.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private let emptyView = PhantomEmptyStateView(emoji: "🎭", title: "No active rules", message: "Intercept or mock network traffic by adding a rule.")
    
    private func showEmptyState() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50)
        ])
    }
    
    private func hideEmptyState() {
        emptyView.removeFromSuperview()
    }
    
    @objc private func addNewRule() {
        let editor = RuleEditorVC()
        navigationController?.pushViewController(editor, animated: true)
    }

    private func startLiveRefresh() {
        stopLiveRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.loadRules()
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func stopLiveRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshRecentActivity() {
        activityStack.arrangedSubviews.forEach { view in
            activityStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let events = PhantomInterceptor.shared.recentEvents(limit: 5)
        guard !events.isEmpty else {
            activityStack.addArrangedSubview(activityEmptyLabel)
            return
        }

        events.map(makeActivityRow).forEach { activityStack.addArrangedSubview($0) }
    }

    private func makeActivityRow(for event: PhantomInterceptor.RecentEvent) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor

        let methodPill = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        methodPill.text = event.method
        methodPill.font = UIFont.phantomMonospaced(size: 10, weight: .bold)
        methodPill.textColor = UIColor.Phantom.neonAzure
        methodPill.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.14)
        methodPill.layer.cornerRadius = 8
        methodPill.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = event.ruleName
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor

        let hostLabel = UILabel()
        hostLabel.text = event.requestURL.host ?? event.requestURL.absoluteString
        hostLabel.font = UIFont.phantomMonospaced(size: 11, weight: .semibold)
        hostLabel.textColor = UIColor.Phantom.vibrantOrange

        let detailLabel = UILabel()
        detailLabel.text = event.actionSummary
        detailLabel.font = .systemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.62)
        detailLabel.numberOfLines = 2

        let pathLabel = UILabel()
        let query = event.requestURL.query.map { "?\($0)" } ?? ""
        pathLabel.text = "\(event.requestURL.path)\(query)"
        pathLabel.font = UIFont.phantomMonospaced(size: 10, weight: .regular)
        pathLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.42)
        pathLabel.numberOfLines = 2

        let timeLabel = UILabel()
        timeLabel.text = relativeTimestamp(for: event.matchedAt)
        timeLabel.font = UIFont.phantomMonospaced(size: 10, weight: .medium)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)

        let headerRow = UIStackView(arrangedSubviews: [methodPill, titleLabel, UIView(), timeLabel])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [headerRow, hostLabel, detailLabel, pathLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    private func relativeTimestamp(for date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 1 { return "now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}

extension InterceptorListVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return rules.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RuleCell", for: indexPath) as! InterceptorCardCell
        let rule = rules[indexPath.item]
        cell.configure(with: rule)
        
        cell.onToggle = { [weak self] isEnabled in
            PhantomInterceptor.shared.toggle(id: rule.id)
            self?.loadRules()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let rule = rules[indexPath.item]
        let alert = UIAlertController(title: "Rule Info", message: "Rule: \(rule.rule.typeDisplayName)\nPattern: \(rule.rule.urlPattern)", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Delete Rule", style: .destructive) { [weak self] _ in
            PhantomInterceptor.shared.delete(id: rule.id)
            self?.loadRules()
        })
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }
}

/// A comprehensive editor for creating advanced interception rules.
internal final class RuleEditorVC: UIViewController {
    private let draft: PhantomInterceptorDraft?
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let dynamicStack = UIStackView()
    private let introCard = UIView()
    
    private let urlTextField = UITextField()
    private let typeSegment = UISegmentedControl(items: ["Block", "Delay", "Mock", "Redirect"])
    
    // Type-specific views
    private let methodSegment = UISegmentedControl(items: ["ALL", "GET", "POST", "PUT", "DELETE"])
    private let statusTextField = UITextField()
    private let headersCodeView = PhantomCodeView()
    private let delayInput = UITextField()
    private let redirectInput = UITextField()
    private let mockBodyView = PhantomCodeView()
    private let previewCard = UIView()
    private let previewSummaryLabel = UILabel()
    private let previewMatchesLabel = UILabel()
    private let previewExamplesLabel = UILabel()

    init(draft: PhantomInterceptorDraft? = nil) {
        self.draft = draft
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyDraftIfNeeded()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "CONFIGURE RULE"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        setupIntroCard()
        stackView.addArrangedSubview(introCard)

        // 1. URL Pattern Section
        addSectionTitle("TARGET URL PATTERN", to: stackView)
        urlTextField.placeholder = "e.g. */api/v1/user*"
        styleTextField(urlTextField)
        stackView.addArrangedSubview(urlTextField)
        
        // 2. Action Type Section
        addSectionTitle("INTERCEPTION ACTION", to: stackView)
        typeSegment.selectedSegmentIndex = 0
        typeSegment.applyPhantomStyle()
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        stackView.addArrangedSubview(typeSegment)

        setupPreviewCard()
        stackView.addArrangedSubview(previewCard)
        
        // 3. Dynamic Inputs
        dynamicStack.axis = .vertical
        dynamicStack.spacing = 24
        stackView.addArrangedSubview(dynamicStack)
        setupDynamicInputs()
        bindPreviewInputs()
        
        // 4. Save Button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Activate Interceptor", for: .normal)
        saveButton.backgroundColor = PhantomTheme.shared.primaryColor
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 16
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        saveButton.addTarget(self, action: #selector(saveRule), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        stackView.addArrangedSubview(saveButton)
        
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
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        updateVisibleInputs()
    }

    private func applyDraftIfNeeded() {
        guard let draft else { return }
        urlTextField.text = draft.urlPattern

        switch draft.kind {
        case .block:
            typeSegment.selectedSegmentIndex = 0
        case .delay:
            typeSegment.selectedSegmentIndex = 1
            delayInput.text = draft.delaySeconds.map { String(format: "%.1f", $0) }
        case .mock:
            typeSegment.selectedSegmentIndex = 2
            if let method = draft.method?.uppercased(),
               let idx = (0..<methodSegment.numberOfSegments).first(where: {
                   methodSegment.titleForSegment(at: $0)?.uppercased() == method
               }) {
                methodSegment.selectedSegmentIndex = idx
            }
            statusTextField.text = draft.statusCode.map(String.init)
            if let data = try? JSONSerialization.data(withJSONObject: draft.headers, options: [.prettyPrinted, .sortedKeys]),
               let headersText = String(data: data, encoding: .utf8) {
                headersCodeView.text = headersText
            }
            mockBodyView.text = draft.bodyText
        case .redirect:
            typeSegment.selectedSegmentIndex = 3
            redirectInput.text = draft.redirectDestination
        }

        updateVisibleInputs()
    }

    private func setupIntroCard() {
        introCard.backgroundColor = PhantomTheme.shared.surfaceColor
        introCard.layer.cornerRadius = 18
        introCard.layer.borderWidth = 1
        introCard.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor

        let icon = UILabel()
        icon.text = "🎯"
        icon.font = .systemFont(ofSize: 30)

        let titleLabel = UILabel()
        titleLabel.text = "Design a rule with intent"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Target stable URL patterns, choose the least invasive action, and keep mocks explicit so captured traffic stays trustworthy."
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.58)
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        introCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: introCard.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: introCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: introCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: introCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupDynamicInputs() {
        methodSegment.selectedSegmentIndex = 0
        methodSegment.applyPhantomStyle()
        
        statusTextField.placeholder = "HTTP Status Code (e.g. 200)"
        statusTextField.keyboardType = .numberPad
        styleTextField(statusTextField)
        
        headersCodeView.isEditable = true
        headersCodeView.text = "{\n  \"Content-Type\": \"application/json\"\n}"
        headersCodeView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        delayInput.placeholder = "Delay in seconds (e.g. 2.5)"
        delayInput.keyboardType = .decimalPad
        styleTextField(delayInput)
        
        redirectInput.placeholder = "Destination URL (e.g. https://dev.api.com/...)"
        styleTextField(redirectInput)
        
        mockBodyView.isEditable = true
        mockBodyView.heightAnchor.constraint(equalToConstant: 200).isActive = true
    }

    private func setupPreviewCard() {
        previewCard.backgroundColor = PhantomTheme.shared.surfaceColor
        previewCard.layer.cornerRadius = 18
        previewCard.layer.borderWidth = 1
        previewCard.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor

        let titleLabel = UILabel()
        titleLabel.text = "Rule Impact Preview"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor

        previewSummaryLabel.font = UIFont.phantomMonospaced(size: 12, weight: .semibold)
        previewSummaryLabel.textColor = UIColor.Phantom.neonAzure
        previewSummaryLabel.numberOfLines = 0

        previewMatchesLabel.font = .systemFont(ofSize: 12, weight: .medium)
        previewMatchesLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.72)
        previewMatchesLabel.numberOfLines = 0

        previewExamplesLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        previewExamplesLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        previewExamplesLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, previewSummaryLabel, previewMatchesLabel, previewExamplesLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        previewCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16)
        ])
    }

    private func bindPreviewInputs() {
        [urlTextField, statusTextField, delayInput, redirectInput].forEach {
            $0.addTarget(self, action: #selector(previewInputsChanged), for: .editingChanged)
        }
        methodSegment.addTarget(self, action: #selector(previewInputsChanged), for: .valueChanged)
        headersCodeView.onTextChange = { [weak self] _ in self?.refreshPreview() }
        mockBodyView.onTextChange = { [weak self] _ in self?.refreshPreview() }
        refreshPreview()
    }
    
    private func addSectionTitle(_ title: String, to stack: UIStackView) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .black)
        label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        label.letterSpacing = 1.2
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(8, after: label)
    }
    
    private func styleTextField(_ tf: UITextField) {
        tf.backgroundColor = PhantomTheme.shared.surfaceColor
        tf.textColor = PhantomTheme.shared.textColor
        tf.font = .systemFont(ofSize: 14, weight: .medium)
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        tf.leftViewMode = .always
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
    
    @objc private func typeChanged() {
        updateVisibleInputs()
        refreshPreview()
    }

    @objc private func previewInputsChanged() {
        refreshPreview()
    }
    
    private func updateVisibleInputs() {
        dynamicStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        switch typeSegment.selectedSegmentIndex {
        case 1: // Delay
            addSectionTitle("DELAY DURATION", to: dynamicStack)
            dynamicStack.addArrangedSubview(delayInput)
        case 2: // Mock
            addSectionTitle("HTTP METHOD", to: dynamicStack)
            dynamicStack.addArrangedSubview(methodSegment)
            
            addSectionTitle("RESPONSE STATUS", to: dynamicStack)
            dynamicStack.addArrangedSubview(statusTextField)
            
            addSectionTitle("RESPONSE HEADERS (JSON)", to: dynamicStack)
            dynamicStack.addArrangedSubview(headersCodeView)
            
            addSectionTitle("RESPONSE BODY", to: dynamicStack)
            dynamicStack.addArrangedSubview(mockBodyView)
        case 3: // Redirect
            addSectionTitle("REDIRECT DESTINATION", to: dynamicStack)
            dynamicStack.addArrangedSubview(redirectInput)
        default: break
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func refreshPreview() {
        let pattern = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let requests = PhantomRequestStore.shared.getAll()

        let actionSummary: String
        switch typeSegment.selectedSegmentIndex {
        case 0:
            actionSummary = "Block matching requests before transport."
        case 1:
            let seconds = TimeInterval(delayInput.text ?? "2.0") ?? 2.0
            actionSummary = String(format: "Inject %.1fs delay into matching requests.", seconds)
        case 2:
            let method = methodSegment.selectedSegmentIndex == 0 ? "ANY" : (methodSegment.titleForSegment(at: methodSegment.selectedSegmentIndex) ?? "ANY")
            let status = Int(statusTextField.text ?? "200") ?? 200
            actionSummary = "Return mocked \(method) response with HTTP \(status)."
        case 3:
            let destination = redirectInput.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            actionSummary = destination.isEmpty ? "Redirect destination not set yet." : "Redirect traffic to \(destination)."
        default:
            actionSummary = "No action configured."
        }
        previewSummaryLabel.text = actionSummary

        guard !pattern.isEmpty else {
            previewMatchesLabel.text = "Enter a URL pattern to estimate impact."
            previewExamplesLabel.text = "Preview uses captured requests in the current session."
            return
        }

        let methodRequirement = typeSegment.selectedSegmentIndex == 2 && methodSegment.selectedSegmentIndex != 0
            ? methodSegment.titleForSegment(at: methodSegment.selectedSegmentIndex)?.uppercased()
            : nil

        let matches = requests.filter { request in
            guard PhantomRuleMatcher.matches(url: request.url, pattern: pattern) else { return false }
            guard let methodRequirement else { return true }
            return request.method.uppercased() == methodRequirement
        }

        previewMatchesLabel.text = "\(matches.count) captured request\(matches.count == 1 ? "" : "s") would match right now."
        if matches.isEmpty {
            previewExamplesLabel.text = "No captured examples yet for this pattern."
        } else {
            let samples = matches.prefix(3).map { "\($0.method) \($0.url.absoluteString)" }
            previewExamplesLabel.text = samples.joined(separator: "\n")
        }
    }
    
    @objc private func saveRule() {
        guard let pattern = urlTextField.text, !pattern.isEmpty else { return }
        
        let rule: InterceptRule
        switch typeSegment.selectedSegmentIndex {
        case 0: // Block
            rule = .block(urlPattern: pattern)
        case 1: // Delay
            let seconds = TimeInterval(delayInput.text ?? "2.0") ?? 2.0
            rule = .delay(urlPattern: pattern, seconds: seconds)
        case 2: // Mock
            let method = methodSegment.selectedSegmentIndex == 0 ? nil : methodSegment.titleForSegment(at: methodSegment.selectedSegmentIndex)
            let statusCode = Int(statusTextField.text ?? "200") ?? 200
            
            var headers: [String: String] = [:]
            if let headersData = headersCodeView.text?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: headersData) as? [String: String] {
                headers = json
            }
            
            let body = mockBodyView.text?.data(using: .utf8)
            rule = .mockResponse(urlPattern: pattern, method: method, statusCode: statusCode, headers: headers, body: body)
        case 3: // Redirect
            let destination = redirectInput.text ?? ""
            guard !destination.isEmpty else { return }
            rule = .redirect(from: pattern, to: destination)
        default:
            return
        }
        
        PhantomInterceptor.shared.add(rule: rule)
        navigationController?.popViewController(animated: true)
    }
}
#endif
