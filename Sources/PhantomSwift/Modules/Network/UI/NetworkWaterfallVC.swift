#if DEBUG
import UIKit

/// Chrome DevTools-style network waterfall timeline visualization.
/// Each row = one request, X axis = time since first request.
internal final class NetworkWaterfallVC: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let timelineHeader = UIView()
    private let statsLabel = UILabel()

    private var requests: [PhantomRequest] = []
    private var barViews: [WaterfallBarView] = []
    private var earliestTime: Date = Date()
    private var totalTimeSpan: TimeInterval = 1.0

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
        loadData()
    }

    // MARK: - Setup

    private func setupStatsBar() {
        statsLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        statsLabel.textAlignment = .center
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

    // MARK: - Data

    private func loadData() {
        requests = PhantomRequestStore.shared.getAll().reversed() // oldest first for timeline
        guard !requests.isEmpty else {
            statsLabel.text = "No requests captured"
            return
        }

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

    // MARK: - Timeline Builder

    private func buildTimeline() {
        let timelineWidth: CGFloat = max(view.bounds.width * 2, 800)
        let totalWidth = timelineLeftMargin + timelineWidth + 20
        let totalHeight = CGFloat(requests.count) * rowHeight + 20

        contentView.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
        contentView.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true

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
