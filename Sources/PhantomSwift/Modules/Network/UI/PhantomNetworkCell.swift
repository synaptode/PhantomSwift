#if DEBUG
import UIKit

/// A premium card-style cell for the Network Trace list.
internal final class PhantomNetworkCell: UITableViewCell {

    // MARK: - Subviews
    private let cardView      = UIView()
    private let statusBar     = UIView()
    private let methodBadge   = UILabel()
    private let pathLabel     = UILabel()
    private let hostLabel     = UILabel()
    private let statusBadge   = UILabel()
    private let metricsLabel  = UILabel()
    private let pendingDot    = UIView()
    private let mockoonBadge  = UILabel()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        setupViews()
        setupConstraints()
    }

    private func setupViews() {
        // Card
        cardView.backgroundColor = PhantomTheme.shared.surfaceColor
        cardView.layer.cornerRadius = 14
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // Left status bar
        statusBar.layer.cornerRadius = 2
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusBar)

        // Method badge pill
        methodBadge.font = .systemFont(ofSize: 9, weight: .black)
        methodBadge.textColor = .white
        methodBadge.textAlignment = .center
        methodBadge.layer.cornerRadius = 5
        methodBadge.clipsToBounds = true
        methodBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(methodBadge)

        // Path
        pathLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pathLabel.textColor = PhantomTheme.shared.textColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(pathLabel)

        // Host
        hostLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hostLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        hostLabel.lineBreakMode = .byTruncatingTail
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(hostLabel)

        // Status code badge
        statusBadge.font = .systemFont(ofSize: 11, weight: .bold)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 5
        statusBadge.clipsToBounds = true
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusBadge)

        // Metrics
        metricsLabel.font = .systemFont(ofSize: 10, weight: .medium)
        metricsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        metricsLabel.textAlignment = .right
        metricsLabel.setContentHuggingPriority(.required, for: .horizontal)
        metricsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(metricsLabel)

        // Pending pulsing dot
        pendingDot.backgroundColor = PhantomTheme.shared.primaryColor
        pendingDot.layer.cornerRadius = 3
        pendingDot.isHidden = true
        pendingDot.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(pendingDot)

        // Mockoon badge — shown when request was Mockoon-redirected
        mockoonBadge.text = " MOCKOON "
        mockoonBadge.font = .systemFont(ofSize: 8, weight: .black)
        mockoonBadge.textColor = .white
        mockoonBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.85)
        mockoonBadge.layer.cornerRadius = 4
        mockoonBadge.clipsToBounds = true
        mockoonBadge.isHidden = true
        mockoonBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(mockoonBadge)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Card inset from contentView
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Left status bar
            statusBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            statusBar.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            statusBar.widthAnchor.constraint(equalToConstant: 4),
            statusBar.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.55),

            // Method badge
            methodBadge.leadingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: 10),
            methodBadge.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            methodBadge.widthAnchor.constraint(equalToConstant: 44),
            methodBadge.heightAnchor.constraint(equalToConstant: 18),

            // Status badge (right side, top aligned with method badge)
            statusBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            statusBadge.centerYAnchor.constraint(equalTo: methodBadge.centerYAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 18),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            // Path label (between method badge and status badge)
            pathLabel.leadingAnchor.constraint(equalTo: methodBadge.trailingAnchor, constant: 8),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusBadge.leadingAnchor, constant: -8),
            pathLabel.centerYAnchor.constraint(equalTo: methodBadge.centerYAnchor),

            // Host label (below path) — leads after Mockoon badge when visible
            hostLabel.leadingAnchor.constraint(equalTo: mockoonBadge.trailingAnchor, constant: 5),
            hostLabel.topAnchor.constraint(equalTo: methodBadge.bottomAnchor, constant: 5),
            hostLabel.trailingAnchor.constraint(lessThanOrEqualTo: metricsLabel.leadingAnchor, constant: -8),
            hostLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            // Metrics label (below status badge, right-aligned)
            metricsLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor),
            metricsLabel.centerYAnchor.constraint(equalTo: hostLabel.centerYAnchor),

            // Pending dot (inside status badge area)
            pendingDot.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            pendingDot.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor),
            pendingDot.widthAnchor.constraint(equalToConstant: 6),
            pendingDot.heightAnchor.constraint(equalToConstant: 6),

            // Mockoon badge (below host label, leading aligned)
            mockoonBadge.leadingAnchor.constraint(equalTo: methodBadge.leadingAnchor),
            mockoonBadge.centerYAnchor.constraint(equalTo: hostLabel.centerYAnchor),
        ])
    }

    // MARK: - Configure
    func configure(with request: PhantomRequest) {
        let statusCode = request.response?.statusCode ?? 0
        let tint = colorForStatus(statusCode, status: request.status)

        configureCoreInfo(request: request, tint: tint)
        configureStatusAndMetrics(request: request, statusCode: statusCode, tint: tint)
        configureBorder(request: request, statusCode: statusCode)
    }

    private func configureCoreInfo(request: PhantomRequest, tint: UIColor) {
        statusBar.backgroundColor = tint

        // Method
        methodBadge.text = request.method.uppercased()
        methodBadge.backgroundColor = colorForMethod(request.method)

        // Path & host
        pathLabel.text = request.url.path.isEmpty ? "/" : request.url.path

        // Mockoon badge
        let isMockoon = request.mockoonRedirectedURL != nil
        mockoonBadge.isHidden = !isMockoon
        // When Mockoon is active, indent the host label to make room for the badge
        hostLabel.text = isMockoon ? request.url.host ?? "" : (request.url.host ?? request.url.absoluteString)
    }

    private func configureStatusAndMetrics(request: PhantomRequest, statusCode: Int, tint: UIColor) {
        let isPending = request.response == nil && !(isBlocked(request) || isFailed(request))
        if isPending {
            configurePendingState()
        } else {
            configureCompletedState(request: request, statusCode: statusCode, tint: tint)
        }
    }

    private func configurePendingState() {
        statusBadge.text = ""
        statusBadge.backgroundColor = .clear
        pendingDot.isHidden = false
        metricsLabel.text = "pending…"
        metricsLabel.textColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.7)
        startPulse()
    }

    private func configureCompletedState(request: PhantomRequest, statusCode: Int, tint: UIColor) {
        pendingDot.isHidden = true
        stopPulse()
        metricsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)

        switch request.status {
        case .blocked:
            statusBadge.text = " BLK "
            statusBadge.textColor = .white
            statusBadge.backgroundColor = UIColor.Phantom.vibrantRed
            metricsLabel.text = "blocked"
        case .failed:
            statusBadge.text = " ERR "
            statusBadge.textColor = .white
            statusBadge.backgroundColor = UIColor.Phantom.error
            metricsLabel.text = "failed"
        case .mocked:
            statusBadge.text = " MOCK "
            statusBadge.textColor = .white
            statusBadge.backgroundColor = UIColor.Phantom.secondary
            metricsLabel.text = formatMetrics(request)
        default:
            if statusCode > 0 {
                statusBadge.text = " \(statusCode) "
                statusBadge.textColor = .white
                statusBadge.backgroundColor = tint
            } else {
                statusBadge.text = ""
                statusBadge.backgroundColor = .clear
            }
            metricsLabel.text = formatMetrics(request)
        }
    }

    private func configureBorder(request: PhantomRequest, statusCode: Int) {
        // Highlight card border for errors
        if statusCode >= 400 || isFailed(request) {
            cardView.layer.borderColor = UIColor.Phantom.error.withAlphaComponent(0.25).cgColor
        } else if statusCode >= 200 && statusCode < 300 {
            cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        } else {
            cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        }
    }

    private func formatMetrics(_ request: PhantomRequest) -> String {
        guard let response = request.response else { return "" }
        let dur = String(format: "%.0fms", response.duration * 1000)
        let size = ByteCountFormatter.string(fromByteCount: Int64(response.body?.count ?? 0), countStyle: .file)
        return "\(dur) · \(size)"
    }

    private func isBlocked(_ request: PhantomRequest) -> Bool {
        if case .blocked = request.status { return true }
        return false
    }

    private func isFailed(_ request: PhantomRequest) -> Bool {
        if case .failed = request.status { return true }
        return false
    }

    // MARK: - Animations
    private func startPulse() {
        guard pendingDot.layer.animation(forKey: "pulse") == nil else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.15
        anim.duration = 0.8
        anim.autoreverses = true
        anim.repeatCount = .infinity
        pendingDot.layer.add(anim, forKey: "pulse")
    }

    private func stopPulse() {
        pendingDot.layer.removeAnimation(forKey: "pulse")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulse()
        pendingDot.isHidden = true
        mockoonBadge.isHidden = true
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        statusBadge.text = nil
        metricsLabel.text = nil
    }

    // MARK: - Colors
    private func colorForStatus(_ code: Int, status: PhantomRequest.RequestStatus) -> UIColor {
        switch status {
        case .completed:
            if code >= 200 && code < 300 { return UIColor.Phantom.success }
            if code >= 400 { return UIColor.Phantom.error }
            return UIColor.Phantom.warning
        case .failed:  return UIColor.Phantom.error
        case .mocked:  return UIColor.Phantom.secondary
        case .blocked: return .systemGray
        case .pending: return PhantomTheme.shared.primaryColor
        }
    }

    private func colorForMethod(_ method: String) -> UIColor {
        switch method.uppercased() {
        case "GET":            return UIColor.Phantom.neonAzure
        case "POST":           return UIColor.Phantom.vibrantPurple
        case "PUT", "PATCH":   return UIColor.Phantom.vibrantOrange
        case "DELETE":         return UIColor.Phantom.vibrantRed
        default:               return PhantomTheme.shared.primaryColor
        }
    }
}
#endif

