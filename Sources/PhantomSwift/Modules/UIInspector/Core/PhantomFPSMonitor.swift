#if DEBUG
import UIKit

// MARK: - PhantomFPSMonitor

/// Real-time performance overlay: FPS, CPU %, and Memory via CADisplayLink + mach APIs.
/// Shows a compact draggable HUD pill; tap it to open the full detail panel.
internal final class PhantomFPSMonitor {

    internal static let shared = PhantomFPSMonitor()

    // MARK: - Public State

    internal private(set) var isRunning = false
    internal private(set) var currentFPS: Double = 0
    internal private(set) var cpuUsage: Double = 0
    internal private(set) var memoryUsedMB: Double = 0
    internal private(set) var fpsHistory: [Double] = []
    internal private(set) var cpuHistory: [Double] = []

    private let historyCapacity = 90

    // MARK: - Private

    private var displayLink: CADisplayLink?
    private var lastSampleTime: CFTimeInterval = 0
    private var framesSinceSample: Int = 0
    private let sampleInterval: CFTimeInterval = 0.5

    private var overlayWindow: FPSOverlayWindow?
    private var hudView: FPSHUDView?

    private init() {}

    // MARK: - Control

    internal func start() {
        guard !isRunning else { return }
        isRunning = true
        framesSinceSample = 0
        lastSampleTime = 0
        setupOverlay()
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    internal func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        overlayWindow?.isHidden = true
        overlayWindow = nil
        hudView = nil
    }

    internal func toggle() {
        isRunning ? stop() : start()
    }

    // MARK: - Display Link Tick

    @objc private func tick(_ link: CADisplayLink) {
        if lastSampleTime == 0 {
            lastSampleTime = link.timestamp
            return
        }
        framesSinceSample += 1
        let elapsed = link.timestamp - lastSampleTime
        guard elapsed >= sampleInterval else { return }

        currentFPS = min(Double(framesSinceSample) / elapsed, 120)
        cpuUsage = Self.sampleCPU()
        memoryUsedMB = Self.sampleMemoryMB()

        appendHistory(&fpsHistory, value: currentFPS)
        appendHistory(&cpuHistory, value: cpuUsage)

        hudView?.update(fps: currentFPS, cpu: cpuUsage, ram: memoryUsedMB, fpsHistory: fpsHistory)

        framesSinceSample = 0
        lastSampleTime = link.timestamp
    }

    private func appendHistory(_ buffer: inout [Double], value: Double) {
        buffer.append(value)
        if buffer.count > historyCapacity { buffer.removeFirst() }
    }

    // MARK: - Sampling (mach APIs)

    private static func sampleCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else { return 0 }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threads)),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }
        var totalCPU: Double = 0
        // THREAD_BASIC_INFO_COUNT = sizeof(thread_basic_info) / sizeof(natural_t)
        let basicInfoCount = mach_msg_type_number_t(
            MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size
        )
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = basicInfoCount
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(basicInfoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            // TH_FLAGS_IDLE = 0x20
            if kr == KERN_SUCCESS && (info.flags & 0x20) == 0 {
                totalCPU += Double(info.cpu_usage) / 1000.0 * 100.0 // TH_USAGE_SCALE = 1000
            }
        }
        return totalCPU
    }

    private static func sampleMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576.0
    }

    // MARK: - Overlay Setup

    private func setupOverlay() {
        let hud = FPSHUDView()
        hud.onTap = { [weak self] in
            guard let self else { return }
            let detailVC = FPSDetailVC(monitor: self)
            let nav = UINavigationController(rootViewController: detailVC)
            if #available(iOS 15.0, *) {
                nav.sheetPresentationController?.detents = [.medium(), .large()]
            } else {
                nav.modalPresentationStyle = .formSheet
            }
            let win = UIApplication.shared.windows.first(where: { !($0 is FPSOverlayWindow) })
            var top = win?.rootViewController
            while let p = top?.presentedViewController { top = p }
            top?.present(nav, animated: true)
        }

        let window = FPSOverlayWindow(hud: hud)
        window.windowLevel = .statusBar + 2
        window.backgroundColor = .clear
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                window.windowScene = scene
            }
        }
        window.makeKeyAndVisible()
        window.resignKey()   // don't steal key status from the app window

        // Position after makeKeyAndVisible so safeAreaInsets are populated
        let safeTop = window.safeAreaInsets.top > 0
            ? window.safeAreaInsets.top
            : (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44)
        hud.frame = CGRect(
            x: window.bounds.width - FPSHUDView.hudSize.width - 12,
            y: safeTop + 8,
            width: FPSHUDView.hudSize.width,
            height: FPSHUDView.hudSize.height
        )

        hudView = hud
        overlayWindow = window
    }
}

// MARK: - FPSOverlayWindow

private final class FPSOverlayWindow: UIWindow {

    private let hudView: FPSHUDView

    init(hud: FPSHUDView) {
        self.hudView = hud
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = .clear
        isUserInteractionEnabled = true

        let safeTop = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44
        hud.frame = CGRect(
            x: bounds.width - FPSHUDView.hudSize.width - 10,
            y: safeTop + 8,
            width: FPSHUDView.hudSize.width,
            height: FPSHUDView.hudSize.height
        )
        addSubview(hud)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        hud.addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func drag(_ gr: UIPanGestureRecognizer) {
        let t = gr.translation(in: self)
        hudView.frame.origin = CGPoint(
            x: hudView.frame.origin.x + t.x,
            y: hudView.frame.origin.y + t.y
        )
        gr.setTranslation(.zero, in: self)

        if gr.state == .ended {
            let size   = hudView.frame.size
            // Use the FPSOverlayWindow's own safeAreaInsets (reliable after layout)
            let safeTop    = self.safeAreaInsets.top
            let safeBottom = self.safeAreaInsets.bottom
            var origin = hudView.frame.origin

            // Snap to nearest horizontal edge with 12px margin
            let margin: CGFloat = 12
            origin.x = origin.x + size.width / 2 < bounds.midX
                ? margin
                : bounds.width - size.width - margin

            // Clamp vertically: don't overlap notch/Dynamic Island or home indicator
            let minY = safeTop + 8
            let maxY = bounds.height - size.height - safeBottom - 8
            origin.y = max(minY, min(origin.y, maxY))

            UIView.animate(
                withDuration: 0.4, delay: 0,
                usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) { self.hudView.frame.origin = origin }
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        hudView.frame.contains(point) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - FPSHUDView

private final class FPSHUDView: UIView {

    internal static let hudSize = CGSize(width: 118, height: 58)
    internal var onTap: (() -> Void)?

    private let fpsLabel = UILabel()
    private let cpuLabel = UILabel()
    private let ramLabel = UILabel()
    private let sparkLayer = CAShapeLayer()
    private var lastFPSData: [Double] = []

    override init(frame: CGRect) {
        super.init(frame: CGRect(origin: .zero, size: FPSHUDView.hudSize))
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.84)
        layer.cornerRadius = 16
        if #available(iOS 13.0, *) { layer.cornerCurve = .continuous }
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // Sparkline at bottom
        sparkLayer.fillColor = UIColor.clear.cgColor
        sparkLayer.strokeColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.5).cgColor
        sparkLayer.lineWidth = 1.5
        sparkLayer.lineCap = .round
        layer.addSublayer(sparkLayer)

        // FPS big number
        fpsLabel.text = "-- fps"
        fpsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .black)
        fpsLabel.textColor = UIColor.Phantom.vibrantGreen
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fpsLabel)

        // CPU
        cpuLabel.text = "CPU --%"
        cpuLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        cpuLabel.textColor = UIColor.Phantom.neonAzure
        cpuLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cpuLabel)

        // RAM
        ramLabel.text = "--- MB"
        ramLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        ramLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        ramLabel.textAlignment = .right
        ramLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ramLabel)

        NSLayoutConstraint.activate([
            fpsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            fpsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            cpuLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            cpuLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),

            ramLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            ramLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    internal func update(fps: Double, cpu: Double, ram: Double, fpsHistory: [Double]) {
        let fpsColor: UIColor = fps >= 55 ? .Phantom.vibrantGreen
                              : fps >= 30 ? .Phantom.vibrantOrange
                              : .Phantom.vibrantRed

        fpsLabel.text = "\(Int(fps.rounded())) fps"
        fpsLabel.textColor = fpsColor
        sparkLayer.strokeColor = fpsColor.withAlphaComponent(0.6).cgColor

        cpuLabel.text = String(format: "CPU %.1f%%", cpu)
        if ram >= 1024 {
            ramLabel.text = String(format: "%.1f GB", ram / 1024)
        } else {
            ramLabel.text = String(format: "%.0f MB", ram)
        }

        lastFPSData = fpsHistory
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sparkLayer.frame = bounds
        drawSparkline()
    }

    private func drawSparkline() {
        let data = lastFPSData
        guard data.count > 1 else { return }
        let w = bounds.width
        let maxH: CGFloat = 10
        let baseline = bounds.maxY - 3
        let step = w / CGFloat(data.count - 1)

        let path = UIBezierPath()
        for (i, v) in data.enumerated() {
            let x = CGFloat(i) * step
            let y = baseline - CGFloat(min(v, 60) / 60.0) * maxH
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        sparkLayer.path = path.cgPath
    }

    @objc private func tapped() { onTap?() }
}

// MARK: - FPSDetailVC

internal final class FPSDetailVC: UIViewController {

    private let monitor: PhantomFPSMonitor
    private var refreshLink: CADisplayLink?

    private let fpsMetric = FPSMetricView(title: "FPS", unit: "", maxValue: 60, barColor: .Phantom.vibrantGreen)
    private let cpuMetric = FPSMetricView(title: "CPU", unit: "%", maxValue: 100, barColor: .Phantom.neonAzure)
    private let ramMetric = FPSMetricView(title: "RAM", unit: "MB", maxValue: 512, barColor: .Phantom.vibrantPurple)
    private let graphView = FPSGraphView()

    internal init(monitor: PhantomFPSMonitor) {
        self.monitor = monitor
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Performance Monitor"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        if #available(iOS 13.0, *) {
            let app = UINavigationBarAppearance()
            app.configureWithOpaqueBackground()
            app.backgroundColor = PhantomTheme.shared.backgroundColor
            app.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = app
            navigationController?.navigationBar.scrollEdgeAppearance = app
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close", style: .done, target: self, action: #selector(close))
        updateToggleButton()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshLink = CADisplayLink(target: self, selector: #selector(refresh))
        refreshLink?.preferredFramesPerSecond = 10
        refreshLink?.add(to: .main, forMode: .common)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshLink?.invalidate()
        refreshLink = nil
    }

    private func setupLayout() {
        let metricsRow = UIStackView(arrangedSubviews: [fpsMetric, cpuMetric, ramMetric])
        metricsRow.axis = .horizontal
        metricsRow.distribution = .fillEqually
        metricsRow.spacing = 12
        metricsRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metricsRow)

        graphView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(graphView)

        let infoCard = buildInfoCard()
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoCard)

        NSLayoutConstraint.activate([
            metricsRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            metricsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            metricsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            metricsRow.heightAnchor.constraint(equalToConstant: 96),

            graphView.topAnchor.constraint(equalTo: metricsRow.bottomAnchor, constant: 16),
            graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            graphView.heightAnchor.constraint(equalToConstant: 130),

            infoCard.topAnchor.constraint(equalTo: graphView.bottomAnchor, constant: 16),
            infoCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func buildInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor

        var rows: [(String, String)] = [
            ("Screen Refresh", "\(UIScreen.main.maximumFramesPerSecond) Hz"),
            ("Device", UIDevice.current.model),
            ("iOS", UIDevice.current.systemVersion),
        ]
        if #available(iOS 11.0, *) {
            let ts: String
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: ts = "Nominal ●"
            case .fair:    ts = "Fair ●"
            case .serious: ts = "Serious ●"
            case .critical:ts = "Critical ●"
            @unknown default: ts = "Unknown"
            }
            rows.append(("Thermal State", ts))
        }
        if #available(iOS 13.0, *) {
            rows.append(("Low Power Mode", ProcessInfo.processInfo.isLowPowerModeEnabled ? "ON" : "OFF"))
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (idx, row) in rows.enumerated() {
            let rowView = UIView()
            rowView.backgroundColor = idx % 2 == 0 ? .clear : UIColor.white.withAlphaComponent(0.03)
            let nameL = UILabel()
            nameL.text = row.0
            nameL.font = .systemFont(ofSize: 13, weight: .medium)
            nameL.textColor = UIColor.white.withAlphaComponent(0.55)
            let valL = UILabel()
            valL.text = row.1
            valL.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            valL.textColor = .white
            valL.textAlignment = .right
            [nameL, valL].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                rowView.addSubview($0)
            }
            NSLayoutConstraint.activate([
                rowView.heightAnchor.constraint(equalToConstant: 40),
                nameL.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
                nameL.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                valL.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -16),
                valL.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            ])
            stack.addArrangedSubview(rowView)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    @objc private func refresh() {
        fpsMetric.value = monitor.currentFPS
        cpuMetric.value = monitor.cpuUsage
        ramMetric.value = monitor.memoryUsedMB
        graphView.fpsData = monitor.fpsHistory
        graphView.cpuData = monitor.cpuHistory
        graphView.setNeedsDisplay()
    }

    @objc private func toggleMonitor() {
        monitor.toggle()
        updateToggleButton()
    }

    private func updateToggleButton() {
        let btn = UIBarButtonItem(
            title: monitor.isRunning ? "Stop" : "Start",
            style: .plain, target: self, action: #selector(toggleMonitor))
        btn.tintColor = monitor.isRunning ? UIColor.Phantom.vibrantRed : UIColor.Phantom.vibrantGreen
        navigationItem.rightBarButtonItem = btn
    }

    @objc private func close() { dismiss(animated: true) }
}

// MARK: - FPSMetricView

private final class FPSMetricView: UIView {

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let barTrack = UIView()
    private let barFill = UIView()
    private var fillWidthConstraint: NSLayoutConstraint?

    private let maxValue: Double
    private let unit: String
    private let barColor: UIColor

    internal var value: Double = 0 {
        didSet { updateDisplay() }
    }

    init(title: String, unit: String, maxValue: Double, barColor: UIColor) {
        self.maxValue = maxValue
        self.unit = unit
        self.barColor = barColor
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        layer.cornerRadius = 14

        titleLabel.font = .systemFont(ofSize: 9, weight: .bold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        valueLabel.text = "--"
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .black)
        valueLabel.textColor = barColor
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        barTrack.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        barTrack.layer.cornerRadius = 2
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(barTrack)

        barFill.backgroundColor = barColor
        barFill.layer.cornerRadius = 2
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(barFill)

        let fillW = barFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint = fillW

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            barTrack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            barTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            barTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            barTrack.heightAnchor.constraint(equalToConstant: 3),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            fillW,
        ])
    }

    private func updateDisplay() {
        let pct = min(value / maxValue, 1.0)
        if unit == "%" {
            valueLabel.text = String(format: "%.1f%%", value)
        } else if unit == "MB" {
            valueLabel.text = value >= 1024
                ? String(format: "%.1fG", value / 1024)
                : String(format: "%.0fM", value)
        } else {
            valueLabel.text = String(format: "%.0f", value)
        }
        UIView.animate(withDuration: 0.25) {
            self.fillWidthConstraint?.constant = self.barTrack.bounds.width * CGFloat(pct)
            self.layoutIfNeeded()
        }
    }
}

// MARK: - FPSGraphView

private final class FPSGraphView: UIView {

    internal var fpsData: [Double] = []
    internal var cpuData: [Double] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = PhantomTheme.shared.surfaceColor
        layer.cornerRadius = 16
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.35),
        ]
        let legendFPSAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.Phantom.vibrantGreen,
        ]
        let legendCPUAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.Phantom.neonAzure.withAlphaComponent(0.8),
        ]

        "HISTORY".draw(at: CGPoint(x: 16, y: 12), withAttributes: titleAttr)
        "■ FPS".draw(at: CGPoint(x: rect.width - 80, y: 12), withAttributes: legendFPSAttr)
        "■ CPU".draw(at: CGPoint(x: rect.width - 40, y: 12), withAttributes: legendCPUAttr)

        // Grid lines
        let plotRect = rect.inset(by: UIEdgeInsets(top: 30, left: 16, bottom: 12, right: 16))
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
        ctx.setLineWidth(0.5)
        for i in 0...3 {
            let y = plotRect.minY + plotRect.height * CGFloat(i) / 3
            ctx.move(to: CGPoint(x: plotRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: plotRect.maxX, y: y))
        }
        ctx.strokePath()

        // 60 fps reference line
        let refY = plotRect.maxY - plotRect.height  // 60fps = 100% of maxFPS 60
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.move(to: CGPoint(x: plotRect.minX, y: refY))
        ctx.addLine(to: CGPoint(x: plotRect.maxX, y: refY))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        drawLine(ctx, data: fpsData, maxValue: 60, inRect: plotRect, color: UIColor.Phantom.vibrantGreen)
        drawLine(ctx, data: cpuData, maxValue: 100, inRect: plotRect, color: UIColor.Phantom.neonAzure.withAlphaComponent(0.7))
    }

    private func drawLine(_ ctx: CGContext, data: [Double], maxValue: Double, inRect r: CGRect, color: UIColor) {
        guard data.count > 1 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let step = r.width / CGFloat(data.count - 1)
        let path = UIBezierPath()
        for (i, v) in data.enumerated() {
            let x = r.minX + CGFloat(i) * step
            let y = r.maxY - CGFloat(min(v, maxValue) / maxValue) * r.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

#endif
