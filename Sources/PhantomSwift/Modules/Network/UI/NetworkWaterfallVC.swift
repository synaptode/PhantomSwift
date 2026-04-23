#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// Chrome DevTools-style network waterfall timeline visualization.
/// Each row = one request, X axis = time since first request.
internal final class NetworkWaterfallVC: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let timelineHeader = UIView()
    private let statsLabel = UILabel()
    private let emptyStateCard = UIView()
    private let emptyStateGlow = UIView()
    private let emptyStateBackdrop = UIView()
    private let emptyStateGradientLayer = CAGradientLayer()
    private let emptyStateIcon = UILabel()
    private let emptyStateTitle = UILabel()
    private let emptyStateMessage = UILabel()
    private let emptyStatePillStack = UIStackView()
    private let emptyStateMiniChart = UIView()

    private var requests: [PhantomRequest] = []
    private var barViews: [WaterfallBarView] = []
    private var earliestTime: Date = Date()
    private var totalTimeSpan: TimeInterval = 1.0
    private var timelineWidthConstraint: NSLayoutConstraint?
    private var timelineHeightConstraint: NSLayoutConstraint?

    // Layout constants
    private let rowHeight: CGFloat = 36
    private let labelWidth: CGFloat = 120
    private let timelineLeftMargin: CGFloat = 130
    private let headerHeight: CGFloat = 44

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Waterfall"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupStatsBar()
        setupTimelineHeader()
        setupScrollView()
        setupEmptyStateCard()
        loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        emptyStateGradientLayer.frame = emptyStateBackdrop.bounds
    }

    // MARK: - Setup

    private func setupStatsBar() {
        statsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        statsLabel.textAlignment = .center
        statsLabel.numberOfLines = 1
        view.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsLabel.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupTimelineHeader() {
        timelineHeader.backgroundColor = PhantomTheme.shared.surfaceColor
        view.addSubview(timelineHeader)
        timelineHeader.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timelineHeader.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 4),
            timelineHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timelineHeader.heightAnchor.constraint(equalToConstant: headerHeight),
        ])
    }

    private func setupScrollView() {
        scrollView.bounces = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: timelineHeader.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }

    private func setupEmptyStateCard() {
        emptyStateCard.backgroundColor = PhantomTheme.shared.surfaceColor
        emptyStateCard.layer.cornerRadius = 22
        emptyStateCard.layer.borderWidth = 1
        emptyStateCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        emptyStateCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emptyStateCard)

        emptyStateBackdrop.backgroundColor = .clear
        emptyStateBackdrop.layer.cornerRadius = 22
        emptyStateBackdrop.clipsToBounds = true
        emptyStateBackdrop.translatesAutoresizingMaskIntoConstraints = false
        emptyStateBackdrop.isUserInteractionEnabled = false
        emptyStateCard.addSubview(emptyStateBackdrop)

        emptyStateGradientLayer.colors = [
            UIColor.Phantom.neonAzure.withAlphaComponent(0.10).cgColor,
            PhantomTheme.shared.surfaceColor.cgColor,
            UIColor.black.withAlphaComponent(0.08).cgColor
        ]
        emptyStateGradientLayer.locations = [0.0, 0.62, 1.0]
        emptyStateGradientLayer.startPoint = CGPoint(x: 0.1, y: 0.0)
        emptyStateGradientLayer.endPoint = CGPoint(x: 0.9, y: 1.0)
        emptyStateBackdrop.layer.insertSublayer(emptyStateGradientLayer, at: 0)

        emptyStateGlow.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.12)
        emptyStateGlow.layer.cornerRadius = 92
        emptyStateGlow.translatesAutoresizingMaskIntoConstraints = false
        emptyStateGlow.isUserInteractionEnabled = false
        emptyStateCard.addSubview(emptyStateGlow)

        let accentStrip = UIView()
        accentStrip.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.85)
        accentStrip.layer.cornerRadius = 2
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        emptyStateCard.addSubview(accentStrip)

        let iconOrb = UIView()
        iconOrb.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.14)
        iconOrb.layer.cornerRadius = 32
        iconOrb.layer.borderWidth = 1
        iconOrb.layer.borderColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.18).cgColor
        iconOrb.translatesAutoresizingMaskIntoConstraints = false
        emptyStateCard.addSubview(iconOrb)

        emptyStateIcon.text = "🌊"
        emptyStateIcon.font = .systemFont(ofSize: 34)
        emptyStateIcon.textAlignment = .center
        emptyStateIcon.translatesAutoresizingMaskIntoConstraints = false
        iconOrb.addSubview(emptyStateIcon)

        emptyStateTitle.text = "Awaiting traffic"
        emptyStateTitle.font = .systemFont(ofSize: 18, weight: .bold)
        emptyStateTitle.textColor = PhantomTheme.shared.textColor
        emptyStateTitle.textAlignment = .center
        emptyStateTitle.numberOfLines = 0
        emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false

        emptyStateMessage.text = "The timeline will appear here once your app sends network requests."
        emptyStateMessage.font = .systemFont(ofSize: 12, weight: .medium)
        emptyStateMessage.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.58)
        emptyStateMessage.textAlignment = .center
        emptyStateMessage.numberOfLines = 0
        emptyStateMessage.translatesAutoresizingMaskIntoConstraints = false

        emptyStateMiniChart.translatesAutoresizingMaskIntoConstraints = false
        emptyStateMiniChart.layer.cornerRadius = 14
        emptyStateMiniChart.layer.borderWidth = 1
        emptyStateMiniChart.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        emptyStateMiniChart.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        emptyStateCard.addSubview(emptyStateMiniChart)

        let barHeights: [CGFloat] = [12, 22, 16, 28, 14]
        let barColors: [UIColor] = [
            UIColor.Phantom.neonAzure,
            UIColor.Phantom.vibrantGreen,
            UIColor.Phantom.neonAzure,
            UIColor.Phantom.vibrantOrange,
            UIColor.Phantom.vibrantGreen
        ]
        let barStack = UIStackView()
        barStack.axis = .horizontal
        barStack.alignment = .bottom
        barStack.distribution = .fillEqually
        barStack.spacing = 8
        barStack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateMiniChart.addSubview(barStack)

        for (index, height) in barHeights.enumerated() {
            let lane = UIView()
            lane.backgroundColor = barColors[index].withAlphaComponent(0.18)
            lane.layer.cornerRadius = 8
            lane.translatesAutoresizingMaskIntoConstraints = false
            lane.heightAnchor.constraint(equalToConstant: height).isActive = true

            let inner = UIView()
            inner.backgroundColor = barColors[index].withAlphaComponent(0.95)
            inner.layer.cornerRadius = 8
            inner.translatesAutoresizingMaskIntoConstraints = false
            lane.addSubview(inner)

            NSLayoutConstraint.activate([
                inner.leadingAnchor.constraint(equalTo: lane.leadingAnchor),
                inner.trailingAnchor.constraint(equalTo: lane.trailingAnchor),
                inner.bottomAnchor.constraint(equalTo: lane.bottomAnchor),
                inner.heightAnchor.constraint(equalTo: lane.heightAnchor)
            ])

            barStack.addArrangedSubview(lane)
        }

        emptyStatePillStack.axis = .horizontal
        emptyStatePillStack.distribution = .fillEqually
        emptyStatePillStack.spacing = 8
        emptyStatePillStack.translatesAutoresizingMaskIntoConstraints = false
        emptyStatePillStack.addArrangedSubview(hintPill(title: "Live timing", accent: UIColor.Phantom.neonAzure))
        emptyStatePillStack.addArrangedSubview(hintPill(title: "Status codes", accent: UIColor.Phantom.vibrantGreen))

        let stack = UIStackView(arrangedSubviews: [emptyStateIcon, emptyStateMiniChart, emptyStateTitle, emptyStateMessage, emptyStatePillStack])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateCard.addSubview(stack)

        NSLayoutConstraint.activate([
            emptyStateCard.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyStateCard.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 8),
            emptyStateCard.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            emptyStateCard.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            emptyStateCard.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            emptyStateCard.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            emptyStateCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -40),
            emptyStateCard.heightAnchor.constraint(equalToConstant: 328),

            emptyStateBackdrop.leadingAnchor.constraint(equalTo: emptyStateCard.leadingAnchor),
            emptyStateBackdrop.trailingAnchor.constraint(equalTo: emptyStateCard.trailingAnchor),
            emptyStateBackdrop.topAnchor.constraint(equalTo: emptyStateCard.topAnchor),
            emptyStateBackdrop.bottomAnchor.constraint(equalTo: emptyStateCard.bottomAnchor),

            emptyStateGlow.centerXAnchor.constraint(equalTo: emptyStateCard.centerXAnchor),
            emptyStateGlow.topAnchor.constraint(equalTo: emptyStateCard.topAnchor, constant: 40),
            emptyStateGlow.widthAnchor.constraint(equalToConstant: 184),
            emptyStateGlow.heightAnchor.constraint(equalToConstant: 184),

            accentStrip.topAnchor.constraint(equalTo: emptyStateCard.topAnchor, constant: 12),
            accentStrip.centerXAnchor.constraint(equalTo: emptyStateCard.centerXAnchor),
            accentStrip.widthAnchor.constraint(equalToConstant: 58),
            accentStrip.heightAnchor.constraint(equalToConstant: 4),

            iconOrb.topAnchor.constraint(equalTo: accentStrip.bottomAnchor, constant: 18),
            iconOrb.centerXAnchor.constraint(equalTo: emptyStateCard.centerXAnchor),
            iconOrb.widthAnchor.constraint(equalToConstant: 64),
            iconOrb.heightAnchor.constraint(equalToConstant: 64),

            emptyStateIcon.centerXAnchor.constraint(equalTo: iconOrb.centerXAnchor),
            emptyStateIcon.centerYAnchor.constraint(equalTo: iconOrb.centerYAnchor),

            emptyStateMiniChart.topAnchor.constraint(equalTo: iconOrb.bottomAnchor, constant: 16),
            emptyStateMiniChart.centerXAnchor.constraint(equalTo: emptyStateCard.centerXAnchor),
            emptyStateMiniChart.widthAnchor.constraint(equalToConstant: 152),
            emptyStateMiniChart.heightAnchor.constraint(equalToConstant: 44),

            barStack.leadingAnchor.constraint(equalTo: emptyStateMiniChart.leadingAnchor, constant: 12),
            barStack.trailingAnchor.constraint(equalTo: emptyStateMiniChart.trailingAnchor, constant: -12),
            barStack.topAnchor.constraint(equalTo: emptyStateMiniChart.topAnchor, constant: 10),
            barStack.bottomAnchor.constraint(equalTo: emptyStateMiniChart.bottomAnchor, constant: -10),

            stack.topAnchor.constraint(equalTo: emptyStateMiniChart.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: emptyStateCard.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: emptyStateCard.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: emptyStateCard.bottomAnchor, constant: -18)
        ])
    }

    // MARK: - Data

    private func loadData() {
        requests = PhantomRequestStore.shared.getAll().reversed() // oldest first for timeline
        guard !requests.isEmpty else {
            statsLabel.text = "No requests captured yet"
            showEmptyState()
            return
        }

        hideEmptyState()
        earliestTime = requests.first?.timestamp ?? Date()
        let latestStart = requests.last?.timestamp ?? earliestTime
        let maxDuration = requests.compactMap { $0.response?.duration }.max() ?? 1.0
        totalTimeSpan = max(latestStart.timeIntervalSince(earliestTime) + maxDuration, 0.5)

        updateStats()
        buildTimeline()
        buildTimelineHeader()
    }

    private func updateStats() {
        let totalReqs = requests.count
        let durations = requests.compactMap { $0.response?.duration }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        let maxDuration = durations.max() ?? 0

        statsLabel.text = "\(totalReqs) requests · avg \(formatDuration(avgDuration)) · max \(formatDuration(maxDuration)) · span \(formatDuration(totalTimeSpan))"
    }

    private func showEmptyState() {
        timelineHeader.isHidden = true
        statsLabel.isHidden = true
        emptyStateCard.isHidden = false
        if emptyStateCard.superview == nil {
            contentView.addSubview(emptyStateCard)
        }

        clearTimeline()
        buildEmptyStateLayout()
    }

    private func hideEmptyState() {
        timelineHeader.isHidden = false
        statsLabel.isHidden = false
        emptyStateCard.isHidden = true
        emptyStateCard.removeFromSuperview()
    }

    // MARK: - Timeline Builder

    private func buildTimeline() {
        emptyStateCard.removeFromSuperview()
        timelineHeader.isHidden = false

        clearTimeline()

        let timelineWidth: CGFloat = max(view.bounds.width * 2, 800)
        let totalWidth = timelineLeftMargin + timelineWidth + 20
        let totalHeight = CGFloat(requests.count) * rowHeight + 20

        timelineWidthConstraint?.isActive = false
        timelineHeightConstraint?.isActive = false
        timelineWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: totalWidth)
        timelineHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: totalHeight)
        timelineWidthConstraint?.isActive = true
        timelineHeightConstraint?.isActive = true

        for (index, request) in requests.enumerated() {
            let y = CGFloat(index) * rowHeight

            // Row background (alternating)
            let rowBg = UIView()
            rowBg.backgroundColor = index % 2 == 0
                ? UIColor.clear
                : PhantomTheme.shared.surfaceColor.withAlphaComponent(0.3)
            rowBg.frame = CGRect(x: 0, y: y, width: totalWidth, height: rowHeight)
            contentView.addSubview(rowBg)

            // Label (method + path)
            let label = UILabel()
            let path = request.url.path.isEmpty ? "/" : request.url.path
            let shortPath = path.count > 18 ? "..." + String(path.suffix(15)) : path
            label.text = "\(request.method) \(shortPath)"
            label.font = .phantomMonospaced(size: 10, weight: .medium)
            label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.8)
            label.frame = CGRect(x: 8, y: y, width: labelWidth - 8, height: rowHeight)
            contentView.addSubview(label)

            // Separator
            let sep = UIView()
            sep.backgroundColor = PhantomTheme.shared.textColor.withAlphaComponent(0.06)
            sep.frame = CGRect(x: labelWidth, y: y, width: 1, height: rowHeight)
            contentView.addSubview(sep)

            // Waterfall bar
            let offset = request.timestamp.timeIntervalSince(earliestTime)
            let duration = request.response?.duration ?? 0.1
            let barX = timelineLeftMargin + CGFloat(offset / totalTimeSpan) * timelineWidth
            let barWidth = max(CGFloat(duration / totalTimeSpan) * timelineWidth, 4)

            let bar = WaterfallBarView()
            bar.configure(request: request)
            bar.frame = CGRect(x: barX, y: y + 6, width: barWidth, height: rowHeight - 12)
            contentView.addSubview(bar)
            barViews.append(bar)

            // Duration label
            if let resp = request.response {
                let durLabel = UILabel()
                durLabel.text = formatDuration(resp.duration)
                durLabel.font = .phantomMonospaced(size: 9, weight: .semibold)
                durLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
                durLabel.sizeToFit()
                durLabel.frame.origin = CGPoint(x: barX + barWidth + 4, y: y + (rowHeight - durLabel.bounds.height) / 2)
                contentView.addSubview(durLabel)
            }
        }
    }

    private func buildEmptyStateLayout() {
        timelineWidthConstraint?.isActive = false
        timelineHeightConstraint?.isActive = false
        timelineWidthConstraint = contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        timelineHeightConstraint = contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        timelineWidthConstraint?.isActive = true
        timelineHeightConstraint?.isActive = true
    }

    private func clearTimeline() {
        barViews.forEach { $0.removeFromSuperview() }
        barViews.removeAll()
        contentView.subviews
            .filter { $0 !== emptyStateCard }
            .forEach { $0.removeFromSuperview() }
    }

    private func hintPill(title: String, accent: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = accent.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 12
        pill.layer.borderWidth = 1
        pill.layer.borderColor = accent.withAlphaComponent(0.18).cgColor

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = accent
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8)
        ])

        return pill
    }

    private func buildTimelineHeader() {
        // Remove old ticks
        timelineHeader.subviews.forEach { $0.removeFromSuperview() }

        let timelineWidth: CGFloat = max(view.bounds.width * 2, 800)
        let tickCount = 10
        let interval = totalTimeSpan / Double(tickCount)

        for i in 0...tickCount {
            let x = timelineLeftMargin + CGFloat(Double(i) / Double(tickCount)) * timelineWidth
            let tick = UIView()
            tick.backgroundColor = PhantomTheme.shared.textColor.withAlphaComponent(0.1)
            tick.frame = CGRect(x: x, y: headerHeight - 10, width: 1, height: 10)
            timelineHeader.addSubview(tick)

            let label = UILabel()
            label.text = formatDuration(interval * Double(i))
            label.font = .phantomMonospaced(size: 9, weight: .medium)
            label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
            label.sizeToFit()
            label.center = CGPoint(x: x, y: headerHeight / 2 - 2)
            timelineHeader.addSubview(label)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 { return "0ms" }
        if seconds < 1.0 { return String(format: "%.0fms", seconds * 1000) }
        return String(format: "%.2fs", seconds)
    }
}

// MARK: - WaterfallBarView

private final class WaterfallBarView: UIView {

    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 4
        if #available(iOS 13.0, *) { layer.cornerCurve = .continuous }
        clipsToBounds = true

        statusLabel.font = .phantomMonospaced(size: 8, weight: .bold)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        addSubview(statusLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(request: PhantomRequest) {
        let statusCode = request.response?.statusCode ?? 0

        switch request.status {
        case .pending:
            backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
            statusLabel.text = "..."
        case .mocked:
            backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.8)
            statusLabel.text = "MOCK"
        case .blocked:
            backgroundColor = UIColor.Phantom.vibrantRed
            statusLabel.text = "BLK"
        case .failed:
            backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.8)
            statusLabel.text = "ERR"
        case .completed:
            if statusCode >= 500 {
                backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.8)
            } else if statusCode >= 400 {
                backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
            } else if statusCode >= 300 {
                backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.6)
            } else {
                backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.8)
            }
            statusLabel.text = "\(statusCode)"
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        statusLabel.frame = bounds
    }
}
#endif
