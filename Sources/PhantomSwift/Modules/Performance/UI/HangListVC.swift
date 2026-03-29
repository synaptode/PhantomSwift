#if DEBUG
import UIKit

/// Displays a list of detected UI hangs/freezes.
internal final class HangListVC: PhantomTableVC {
    private var hangs: [PhantomHangEvent] = []

    // MARK: - Empty State
    private lazy var hangEmptyStateView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = "✅"
        icon.font = .systemFont(ofSize: 48)

        let title = UILabel()
        title.text = "No Hangs Detected"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = PhantomTheme.shared.textColor

        let sub = UILabel()
        sub.text = "The main thread is running smoothly.\nFreeze events will appear here."
        sub.font = .systemFont(ofSize: 14, weight: .regular)
        sub.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        sub.textAlignment = .center
        sub.numberOfLines = 0

        [icon, title, sub].forEach { stack.addArrangedSubview($0) }
        v.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: v.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -32)
        ])
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Main Thread Hangs"
        setupNavigation()
        setupTableView()
        setupValueObservation()
    }

    private func setupTableView() {
        tableView.register(HangEventCell.self, forCellReuseIdentifier: "HangCell")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear Logs",
            style: .plain,
            target: self,
            action: #selector(clearLogs)
        )
    }

    private func setupValueObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: NSNotification.Name("PhantomHangDetected"),
            object: nil
        )
        reloadData()
    }

    @objc private func reloadData() {
        self.hangs = PhantomHangDetector.shared.hangs.reversed()
        self.tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        if hangs.isEmpty {
            if hangEmptyStateView.superview == nil {
                view.addSubview(hangEmptyStateView)
                NSLayoutConstraint.activate([
                    hangEmptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
                    hangEmptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    hangEmptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    hangEmptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
            }
            hangEmptyStateView.isHidden = false
        } else {
            hangEmptyStateView.isHidden = true
        }
    }

    @objc private func clearLogs() {
        PhantomHangDetector.shared.clearLogs()
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hangs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HangCell", for: indexPath) as? HangEventCell else {
            return UITableViewCell()
        }
        let hang = hangs[indexPath.row]
        cell.configure(with: hang)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let hang = hangs[indexPath.row]
        let detailVC = HangDetailVC(hang: hang)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - HangEventCell

private final class HangEventCell: UITableViewCell {

    // Container
    private let containerView     = UIView()

    // Icon
    private let iconContainer     = UIView()
    private let iconLabel         = UILabel()

    // Top row: duration + badge
    private let topRow            = UIStackView()
    private let durationLabel     = UILabel()
    private let severityBadge     = UIView()
    private let severityLabel     = UILabel()

    // Info stack
    private let infoStack         = UIStackView()
    private let screenLabel       = UILabel()
    private let timestampLabel    = UILabel()

    // Bottom intensity bar
    private let intensityBar      = UIView()
    private let intensityFill     = UIView()

    private var intensityWidthConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle  = .none

        // Container
        containerView.backgroundColor   = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.6)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth  = 1
        containerView.layer.borderColor  = UIColor.white.withAlphaComponent(0.08).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Icon container
        iconContainer.backgroundColor       = UIColor.Phantom.vibrantRed.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius    = 14
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconContainer)

        iconLabel.text  = "❄️"
        iconLabel.font  = .systemFont(ofSize: 22)
        iconLabel.setContentHuggingPriority(.required, for: .horizontal)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconLabel)

        // Severity badge
        severityBadge.layer.cornerRadius    = 6
        severityBadge.translatesAutoresizingMaskIntoConstraints = false

        severityLabel.font                  = .systemFont(ofSize: 10, weight: .black)
        severityLabel.textColor             = .white
        severityLabel.numberOfLines         = 1
        severityLabel.setContentHuggingPriority(.required, for: .horizontal)
        severityLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        severityLabel.translatesAutoresizingMaskIntoConstraints = false
        severityBadge.addSubview(severityLabel)

        // Duration label
        durationLabel.font  = .systemFont(ofSize: 26, weight: .black)
        durationLabel.textColor = PhantomTheme.shared.textColor
        durationLabel.adjustsFontSizeToFitWidth = false
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Top row (horizontal: duration + badge + spacer)
        topRow.axis         = .horizontal
        topRow.alignment    = .center
        topRow.spacing      = 10
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.addArrangedSubview(durationLabel)
        topRow.addArrangedSubview(severityBadge)
        let topSpacer = UIView()
        topSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topRow.addArrangedSubview(topSpacer)

        // Screen label
        screenLabel.font                = .systemFont(ofSize: 13, weight: .semibold)
        screenLabel.textColor           = PhantomTheme.shared.primaryColor
        screenLabel.numberOfLines       = 2
        screenLabel.lineBreakMode       = .byWordWrapping
        screenLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        screenLabel.translatesAutoresizingMaskIntoConstraints = false

        // Timestamp label
        timestampLabel.font             = .systemFont(ofSize: 11, weight: .medium)
        timestampLabel.textColor        = PhantomTheme.shared.textColor.withAlphaComponent(0.45)
        timestampLabel.numberOfLines    = 1
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false

        // Info stack (vertical: screenLabel + timestamp)
        infoStack.axis      = .vertical
        infoStack.alignment = .leading
        infoStack.spacing   = 3
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.addArrangedSubview(screenLabel)
        infoStack.addArrangedSubview(timestampLabel)

        // Intensity bar
        intensityBar.backgroundColor    = PhantomTheme.shared.textColor.withAlphaComponent(0.06)
        intensityBar.layer.cornerRadius = 2.5
        intensityBar.clipsToBounds      = true
        intensityBar.translatesAutoresizingMaskIntoConstraints = false

        intensityFill.layer.cornerRadius = 2.5
        intensityFill.translatesAutoresizingMaskIntoConstraints = false
        intensityBar.addSubview(intensityFill)

        // Add all to container
        [topRow, infoStack, intensityBar].forEach { containerView.addSubview($0) }

        // MARK: Constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Icon container (top-left)
            iconContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),

            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            // Top row (duration + badge): right side of icon
            topRow.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            topRow.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            topRow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            // Severity badge internal padding
            severityLabel.topAnchor.constraint(equalTo: severityBadge.topAnchor, constant: 3),
            severityLabel.leadingAnchor.constraint(equalTo: severityBadge.leadingAnchor, constant: 7),
            severityLabel.trailingAnchor.constraint(equalTo: severityBadge.trailingAnchor, constant: -7),
            severityLabel.bottomAnchor.constraint(equalTo: severityBadge.bottomAnchor, constant: -3),

            // Info stack below top row, pinned to same leading, full trailing
            infoStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            infoStack.leadingAnchor.constraint(equalTo: topRow.leadingAnchor),
            infoStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            // Intensity bar at the bottom
            intensityBar.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 14),
            intensityBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            intensityBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            intensityBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -18),
            intensityBar.heightAnchor.constraint(equalToConstant: 5),

            // Intensity fill (width set dynamically)
            intensityFill.leadingAnchor.constraint(equalTo: intensityBar.leadingAnchor),
            intensityFill.topAnchor.constraint(equalTo: intensityBar.topAnchor),
            intensityFill.bottomAnchor.constraint(equalTo: intensityBar.bottomAnchor),
        ])
    }

    // MARK: - Configure

    func configure(with hang: PhantomHangEvent) {
        durationLabel.text = String(format: "%.2fs", hang.duration)

        let screenName = hang.screenName
        screenLabel.text = "at \(screenName)"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        timestampLabel.text = "🕒 \(formatter.string(from: hang.timestamp))"

        let color: UIColor
        let severity: String
        let percent: CGFloat

        if hang.duration > 1.5 {
            color    = UIColor.Phantom.error
            severity = "CRITICAL FREEZE"
            percent  = 1.0
        } else if hang.duration > 0.8 {
            color    = UIColor.Phantom.warning
            severity = "MAJOR HANG"
            percent  = 0.65
        } else {
            color    = UIColor.Phantom.electricIndigo
            severity = "MINOR HITCH"
            percent  = 0.32
        }

        severityBadge.backgroundColor = color
        severityLabel.text            = severity
        durationLabel.textColor       = color
        intensityFill.backgroundColor = color

        // Gradient tint on icon background
        iconContainer.backgroundColor = color.withAlphaComponent(0.12)

        // Dynamic width for intensity fill
        intensityWidthConstraint?.isActive = false
        intensityWidthConstraint = intensityFill.widthAnchor.constraint(
            equalTo: intensityBar.widthAnchor,
            multiplier: max(0.01, percent)
        )
        intensityWidthConstraint?.isActive = true
    }
}
#endif
