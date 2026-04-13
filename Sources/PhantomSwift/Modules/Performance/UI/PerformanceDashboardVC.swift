#if DEBUG
import UIKit
import MetricKit

/// Displays real-time performance metrics in a dashboard.
internal final class PerformanceDashboardVC: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statsStack = UIStackView()

    private let fpsCard = MetricView(title: "Frame Rate", unit: "FPS", icon: "gauge.with.needle")
    private let cpuCard = MetricView(title: "CPU Usage", unit: "%", icon: "cpu")
    private let ramCard = MetricView(title: "Memory", unit: "MB", icon: "memorychip")

    // MetricKit section (iOS 13+)
    private let metricKitSection = UIView()
    private var metricKitContainer: UIStackView?

    // Memory Tools section
    private let footprintLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Performance"
        setupUI()
        startMonitoring()
        setupMemoryDiffButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PerformanceMonitor.shared.onUpdate = nil
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Performance"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        
        setupHeroCard(in: container)
        setupStatsGrid(in: container)
        setupMetricKitSection(in: container)
        setupMemoryToolsSection(in: container)
        setupConstraints(container: container)
    }

    private func setupHeroCard(in container: UIStackView) {
        let fpsHeader = UILabel()
        fpsHeader.text = "FLUIDITY"
        fpsHeader.font = UIFont.systemFont(ofSize: 10, weight: .black)
        fpsHeader.textColor = PhantomTheme.shared.primaryColor
        container.addArrangedSubview(fpsHeader)
        container.addArrangedSubview(fpsCard)
    }

    private func setupStatsGrid(in container: UIStackView) {
        let statsHeader = UILabel()
        statsHeader.text = "SYSTEM LOAD"
        statsHeader.font = UIFont.systemFont(ofSize: 10, weight: .black)
        statsHeader.textColor = PhantomTheme.shared.primaryColor
        container.addArrangedSubview(statsHeader)
        
        statsStack.axis = .horizontal
        statsStack.spacing = 15
        statsStack.distribution = .fillEqually
        statsStack.addArrangedSubview(cpuCard)
        statsStack.addArrangedSubview(ramCard)
        container.addArrangedSubview(statsStack)
    }

    private func setupMetricKitSection(in container: UIStackView) {
        if #available(iOS 13.0, *) {
            let mkHeader = UILabel()
            mkHeader.text = "METRICKIT (24H)"
            mkHeader.font = UIFont.systemFont(ofSize: 10, weight: .black)
            mkHeader.textColor = PhantomTheme.shared.primaryColor
            container.addArrangedSubview(mkHeader)

            let mkStack = UIStackView()
            mkStack.axis = .vertical
            mkStack.spacing = 0
            mkStack.layer.cornerRadius = 16
            mkStack.clipsToBounds = true
            container.addArrangedSubview(mkStack)
            metricKitContainer = mkStack

            renderMetricKitContent()

            PhantomMetricKitMonitor.shared.addObserver { [weak self] in
                self?.renderMetricKitContent()
            }
            PhantomMetricKitMonitor.shared.start()
        }
    }

    private func setupMemoryToolsSection(in container: UIStackView) {
        let memHeader = UILabel()
        memHeader.text      = "MEMORY TOOLS"
        memHeader.font      = UIFont.systemFont(ofSize: 10, weight: .black)
        memHeader.textColor = PhantomTheme.shared.primaryColor
        container.addArrangedSubview(memHeader)

        let memCard = UIView()
        memCard.backgroundColor = PhantomTheme.shared.surfaceColor
        memCard.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { memCard.layer.cornerCurve = .continuous }
        container.addArrangedSubview(memCard)

        // Footprint row
        let fpTitleLabel = UILabel()
        fpTitleLabel.text      = "RESIDENT SIZE"
        fpTitleLabel.font      = UIFont.systemFont(ofSize: 9, weight: .black)
        fpTitleLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        fpTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        memCard.addSubview(fpTitleLabel)

        footprintLabel.text      = "— MB"
        footprintLabel.font      = UIFont.phantomMonospaced(size: 28, weight: .bold)
        footprintLabel.textColor = PhantomTheme.shared.textColor
        footprintLabel.translatesAutoresizingMaskIntoConstraints = false
        memCard.addSubview(footprintLabel)

        let divider1 = makeDivider()
        divider1.translatesAutoresizingMaskIntoConstraints = false
        memCard.addSubview(divider1)

        // Action rows inside memCard
        let warnRow  = makeMemoryActionRow(title: "Simulate Memory Warning",
                                           icon: "exclamationmark.triangle.fill",
                                           color: UIColor.Phantom.vibrantOrange,
                                           action: #selector(simulateWarning))
        let cacheRow = makeMemoryActionRow(title: "Clear All Caches",
                                           icon: "trash.fill",
                                           color: UIColor.Phantom.neonAzure,
                                           action: #selector(clearCaches))
        let diffRow  = makeMemoryActionRow(title: "Memory Diff →",
                                           icon: "arrow.left.arrow.right",
                                           color: UIColor.Phantom.vibrantGreen,
                                           action: #selector(openMemoryDiff))

        let divider2 = makeDivider()
        let divider3 = makeDivider()
        [warnRow, divider2, cacheRow, divider3, diffRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            memCard.addSubview($0)
        }

        NSLayoutConstraint.activate([
            fpTitleLabel.topAnchor.constraint(equalTo: memCard.topAnchor, constant: 14),
            fpTitleLabel.leadingAnchor.constraint(equalTo: memCard.leadingAnchor, constant: 16),

            footprintLabel.topAnchor.constraint(equalTo: fpTitleLabel.bottomAnchor, constant: 2),
            footprintLabel.leadingAnchor.constraint(equalTo: memCard.leadingAnchor, constant: 14),

            divider1.topAnchor.constraint(equalTo: footprintLabel.bottomAnchor, constant: 12),
            divider1.leadingAnchor.constraint(equalTo: memCard.leadingAnchor),
            divider1.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),

            warnRow.topAnchor.constraint(equalTo: divider1.bottomAnchor),
            warnRow.leadingAnchor.constraint(equalTo: memCard.leadingAnchor),
            warnRow.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),

            divider2.topAnchor.constraint(equalTo: warnRow.bottomAnchor),
            divider2.leadingAnchor.constraint(equalTo: memCard.leadingAnchor, constant: 16),
            divider2.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),

            cacheRow.topAnchor.constraint(equalTo: divider2.bottomAnchor),
            cacheRow.leadingAnchor.constraint(equalTo: memCard.leadingAnchor),
            cacheRow.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),

            divider3.topAnchor.constraint(equalTo: cacheRow.bottomAnchor),
            divider3.leadingAnchor.constraint(equalTo: memCard.leadingAnchor, constant: 16),
            divider3.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),

            diffRow.topAnchor.constraint(equalTo: divider3.bottomAnchor),
            diffRow.leadingAnchor.constraint(equalTo: memCard.leadingAnchor),
            diffRow.trailingAnchor.constraint(equalTo: memCard.trailingAnchor),
            diffRow.bottomAnchor.constraint(equalTo: memCard.bottomAnchor),
        ])
    }

    private func setupConstraints(container: UIStackView) {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            fpsCard.heightAnchor.constraint(equalToConstant: 200),
            statsStack.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    private func startMonitoring() {
        PerformanceMonitor.shared.start()
        PerformanceMonitor.shared.onUpdate = { [weak self] data in
            self?.fpsCard.value = "\(data.fps)"
            self?.cpuCard.value = String(format: "%.1f", data.cpu)
            self?.ramCard.value = "\(data.ram / 1024 / 1024)"

            // Status coding
            self?.fpsCard.updateStatus(data.fps > 55 ? .success : (data.fps > 30 ? .warning : .error))
            self?.cpuCard.updateStatus(data.cpu < 50 ? .success : (data.cpu < 80 ? .warning : .error))
            self?.ramCard.updateStatus(data.ram < 500 * 1024 * 1024 ? .success : .warning)

            // Update Timelines
            let history = PerformanceMonitor.shared.history
            self?.fpsCard.updateTimeline(with: history.map { Double($0.fps) })
            self?.cpuCard.updateTimeline(with: history.map { $0.cpu })
            self?.ramCard.updateTimeline(with: history.map { Double($0.ram) / 1024 / 1024 })

            let fp = PhantomMemorySlayer.shared.currentFootprintBytes()
            self?.footprintLabel.text = PhantomMemorySlayer.formatBytes(fp)
        }
    }

    // MARK: - Memory Tools helpers

    private func setupMemoryDiffButton() {
        let diffItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            let cfg = PhantomSymbolConfig(pointSize: 13, weight: .semibold)
            diffItem = UIBarButtonItem(
                image: UIImage.phantomSymbol("arrow.left.arrow.right", config: cfg),
                style: .plain, target: self, action: #selector(openMemoryDiff))
        } else {
            diffItem = UIBarButtonItem(
                title: "Diff", style: .plain,
                target: self, action: #selector(openMemoryDiff))
        }
        diffItem.tintColor = UIColor.Phantom.vibrantGreen
        navigationItem.rightBarButtonItem = diffItem
    }

    private func makeMemoryActionRow(title: String, icon: String,
                                     color: UIColor, action: Selector) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        if #available(iOS 13.0, *) {
            let cfg      = PhantomSymbolConfig(pointSize: 14, weight: .semibold)
            let iconView = UIImageView(image: UIImage.phantomSymbol(icon, config: cfg))
            iconView.tintColor        = color
            iconView.contentMode      = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 18),
                iconView.heightAnchor.constraint(equalToConstant: 18),
            ])
        }

        let titleLabel = UILabel()
        titleLabel.text      = title
        titleLabel.font      = .systemFont(ofSize: 13)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 42),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: action, for: .touchUpInside)
        row.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            btn.topAnchor.constraint(equalTo: row.topAnchor),
            btn.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    @objc private func simulateWarning() {
        PhantomMemorySlayer.shared.simulateMemoryWarning()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    @objc private func clearCaches() {
        PhantomMemorySlayer.shared.clearCaches()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func openMemoryDiff() {
        navigationController?.pushViewController(MemoryDiffVC(), animated: true)
    }

    // MARK: - MetricKit Rendering

    @available(iOS 13.0, *)
    private func renderMetricKitContent() {
        guard let stack = metricKitContainer else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let metric = PhantomMetricKitMonitor.shared.latestMetric {
            let rows: [(String, String, String)] = [
                ("clock.fill",         "First Draw",       metric.timeToFirstDraw.map { "\(Int($0)) ms" } ?? "—"),
                ("bolt.fill",          "Resume Time",      metric.applicationResumeTime.map { "\(Int($0)) ms" } ?? "—"),
                ("exclamationmark.triangle.fill", "Hang Duration", metric.hangDuration.map { "\(Int($0)) ms" } ?? "—"),
                ("cpu",                "CPU Time",         metric.cpuTime.map { String(format: "%.1f s", $0) } ?? "—"),
                ("memorychip",         "Peak Memory",      metric.peakMemoryUsage.map { formatBytes($0) } ?? "—"),
                ("externaldrive.fill", "Disk Writes",      metric.cumulativeLogicalWrites.map { formatBytes($0) } ?? "—"),
            ]

            for (icon, label, value) in rows {
                stack.addArrangedSubview(metricRow(icon: icon, label: label, value: value))
            }

            if let diag = PhantomMetricKitMonitor.shared.latestDiagnostic {
                let divider = makeDivider()
                stack.addArrangedSubview(divider)
                stack.addArrangedSubview(metricRow(icon: "ant.fill",          label: "Crashes",       value: "\(diag.crashCount)",           accent: diag.crashCount > 0 ? UIColor.Phantom.vibrantRed : nil))
                stack.addArrangedSubview(metricRow(icon: "hand.raised.slash",  label: "Hangs",         value: "\(diag.hangCount)",            accent: diag.hangCount > 0 ? UIColor.Phantom.vibrantOrange : nil))
                stack.addArrangedSubview(metricRow(icon: "cpu",                label: "CPU Exceptions",value: "\(diag.cpuExceptionCount)",    accent: diag.cpuExceptionCount > 0 ? UIColor.Phantom.vibrantOrange : nil))
            }

            let footer = UILabel()
            footer.text = "  Received: \(formatDate(metric.receivedAt))  •  App \(metric.appVersion)"
            footer.font = .systemFont(ofSize: 10)
            footer.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
            footer.backgroundColor = PhantomTheme.shared.surfaceColor
            stack.addArrangedSubview(footer)
        } else {
            let placeholder = UILabel()
            placeholder.text = "  MetricKit data delivered within 24h of installation or next day."
            placeholder.font = .systemFont(ofSize: 13)
            placeholder.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
            placeholder.numberOfLines = 0
            placeholder.backgroundColor = PhantomTheme.shared.surfaceColor
            placeholder.textAlignment = .center
            let inset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
            stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: inset.top, leading: inset.left, bottom: inset.bottom, trailing: inset.right)
            stack.isLayoutMarginsRelativeArrangement = true
            stack.addArrangedSubview(placeholder)
        }
    }

    @available(iOS 13.0, *)
    private func metricRow(icon: String, label: String, value: String, accent: UIColor? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = PhantomTheme.shared.surfaceColor

        let imageView = UIImageView()
        if #available(iOS 13.0, *) {
            imageView.image = UIImage(systemName: icon)
        }
        imageView.tintColor = accent ?? PhantomTheme.shared.primaryColor.withAlphaComponent(0.7)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 13)
        labelView.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.75)
        labelView.translatesAutoresizingMaskIntoConstraints = false

        let valueView = UILabel()
        valueView.text = value
        valueView.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        valueView.textColor = accent ?? PhantomTheme.shared.textColor
        valueView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        container.addSubview(labelView)
        container.addSubview(valueView)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            labelView.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            valueView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func formatBytes(_ bytes: Double) -> String {
        let mb = bytes / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", bytes / 1024)
    }

    private func formatDate(_ date: Date) -> String {
        return SessionSummaryCell.dateFormatter.string(from: date)
    }
}

private final class MetricView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let statusCard = UIView()
    private let statusLabel = UILabel()
    private let timelineView = PhantomTimelineView()
    
    var value: String? {
        get { return valueLabel.text }
        set { valueLabel.text = newValue }
    }
    
    init(title: String, unit: String, icon: String) {
        super.init(frame: .zero)
        titleLabel.text = title.uppercased()
        unitLabel.text = unit
        if #available(iOS 13.0, *) {
            iconView.image = UIImage(systemName: icon)
        } else {
            // iOS 12 Fallback text is placed in init usually, skipping since it's just decorative.
        }
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        layer.cornerRadius = 24
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        
        iconView.tintColor = PhantomTheme.shared.primaryColor
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .black)
        titleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        addSubview(titleLabel)
        
        valueLabel.font = UIFont.phantomMonospaced(size: 32, weight: .bold)
        valueLabel.textColor = PhantomTheme.shared.textColor
        addSubview(valueLabel)
        
        unitLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        unitLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.3)
        addSubview(unitLabel)
        
        statusCard.layer.cornerRadius = 8
        addSubview(statusCard)
        
        statusLabel.font = UIFont.systemFont(ofSize: 8, weight: .black)
        statusLabel.textColor = .white
        statusCard.addSubview(statusLabel)
        
        timelineView.lineColor = PhantomTheme.shared.primaryColor
        addSubview(timelineView)
        
        [iconView, titleLabel, valueLabel, unitLabel, statusCard, statusLabel, timelineView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            statusCard.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            statusCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusCard.heightAnchor.constraint(equalToConstant: 16),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -6),
            statusLabel.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor),
            
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            
            unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            unitLabel.bottomAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: -6),
            
            timelineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            timelineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            timelineView.bottomAnchor.constraint(equalTo: bottomAnchor),
            timelineView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4)
        ])
    }
    
    func updateTimeline(with points: [Double]) {
        timelineView.update(with: points)
    }
    
    enum Status: String { 
        case success = "OPTIMAL"
        case warning = "HEAVY"
        case error = "CRITICAL"
    }
    
    func updateStatus(_ status: Status) {
        statusLabel.text = status.rawValue
        switch status {
        case .success: statusCard.backgroundColor = UIColor.Phantom.success
        case .warning: statusCard.backgroundColor = UIColor.Phantom.warning
        case .error: statusCard.backgroundColor = UIColor.Phantom.error
        }
    }
}
#endif
