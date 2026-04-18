#if DEBUG
import UIKit

/// Captures screenshots and system state for bug reporting.
public final class PhantomBugReporter {
    public static let shared = PhantomBugReporter()

    private init() {}

    /// Captures the current screen and opens the reporter.
    public func initiateReport() {
        guard let window = PhantomPresentationResolver.activeHostWindow(),
              let screenshot = captureScreenshot(window: window) else { return }

        let reporterVC = BugReporterVC(screenshot: screenshot)
        let nav = UINavigationController(rootViewController: reporterVC)
        nav.modalPresentationStyle = .fullScreen

        PhantomPresentationResolver.topPresenter()?.present(nav, animated: true)
    }

    private func captureScreenshot(window: UIWindow) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, 0)
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    // MARK: - Diagnostic Bundle

    /// Creates a .zip diagnostic bundle with screenshot, logs, network trace, performance data, and device info.
    internal func buildDiagnosticBundle(screenshot: UIImage, annotatedImage: UIImage?) -> URL? {
        let fm = FileManager.default
        let bundleDir = fm.temporaryDirectory.appendingPathComponent("PhantomBugReport_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: bundleDir, withIntermediateDirectories: true)

            // 1. Screenshot
            if let data = screenshot.pngData() {
                try data.write(to: bundleDir.appendingPathComponent("screenshot.png"))
            }

            // 2. Annotated screenshot
            if let annotated = annotatedImage, let data = annotated.pngData() {
                try data.write(to: bundleDir.appendingPathComponent("annotated_screenshot.png"))
            }

            // 3. Device info
            let deviceInfo = buildDeviceInfo()
            try deviceInfo.write(to: bundleDir.appendingPathComponent("device_info.txt"),
                                 atomically: true, encoding: .utf8)

            // 4. Recent logs (last 100)
            let logs = LogStore.shared.getAll().suffix(100)
            let logText = logs.map { "[\($0.level.emoji)] \($0.timestamp) | \($0.message)" }.joined(separator: "\n")
            try logText.write(to: bundleDir.appendingPathComponent("recent_logs.txt"),
                              atomically: true, encoding: .utf8)

            // 5. Network trace (last 30 seconds)
            let cutoff = Date().addingTimeInterval(-30)
            let recentRequests = PhantomRequestStore.shared.getAll().filter { $0.timestamp > cutoff }
            if let harData = PhantomHARExporter.shared.generateHAR(from: recentRequests) {
                try harData.write(to: bundleDir.appendingPathComponent("network_trace.har"))
            }

            // 6. Performance snapshot
            let perfData = buildPerformanceSnapshot()
            try perfData.write(to: bundleDir.appendingPathComponent("performance.txt"),
                               atomically: true, encoding: .utf8)

            // Create zip
            let zipURL = fm.temporaryDirectory.appendingPathComponent("PhantomBugReport.zip")
            if fm.fileExists(atPath: zipURL.path) {
                do {
                    try fm.removeItem(at: zipURL)
                } catch {
                    print("PhantomSwift Error: Could not remove existing zip file: \(error.localizedDescription)")
                }
            }

            let coordinator = NSFileCoordinator()
            var error: NSError?
            var copyError: Error?
            coordinator.coordinate(readingItemAt: bundleDir,
                                   options: .forUploading,
                                   error: &error) { (zippedURL) in
                do {
                    try fm.copyItem(at: zippedURL, to: zipURL)
                } catch {
                    copyError = error
                }
            }

            // Clean up bundle dir
            do {
                try fm.removeItem(at: bundleDir)
            } catch {
                print("PhantomSwift Error: Could not clean up bundle directory: \(error.localizedDescription)")
            }

            if copyError == nil && error == nil && fm.fileExists(atPath: zipURL.path) {
                return zipURL
            }
        } catch {
            // Silently fail in debug tool
        }

        return nil
    }

    private func buildDeviceInfo() -> String {
        let device = UIDevice.current
        var info = """
        PhantomSwift Bug Report
        =======================
        Date: \(Date())
        Device: \(device.model)
        System: \(device.systemName) \(device.systemVersion)
        Name: \(device.name)
        """

        if let bundleID = Bundle.main.bundleIdentifier {
            info += "\nBundle ID: \(bundleID)"
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info += "\nApp Version: \(version)"
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info += "\nBuild: \(build)"
        }

        let pm = PerformanceMonitor.shared
        info += "\nCurrent FPS: \(pm.currentFPS)"

        return info
    }

    private func buildPerformanceSnapshot() -> String {
        let pm = PerformanceMonitor.shared
        let history = pm.history.suffix(10)
        var text = "Performance Snapshot\n====================\n"
        text += "Current FPS: \(pm.currentFPS)\n\n"
        text += "Recent History (last 10 samples):\n"
        for data in history {
            text += "FPS: \(data.fps) | CPU: \(String(format: "%.1f", data.cpu))% | RAM: \(String(format: "%.1f", data.ram)) MB\n"
        }
        return text
    }
}

// MARK: - BugReporterVC with Annotation

/// An advanced bug reporter with freehand drawing annotation and diagnostic bundle export.
internal final class BugReporterVC: UIViewController {
    private let screenshot: UIImage
    private let imageView = UIImageView()
    private let canvasView = DrawingCanvasView()
    private let toolbar = UIView()

    // Drawing tools
    private var selectedColor: UIColor = .red
    private var brushWidth: CGFloat = 3.0
    private let colors: [UIColor] = [.red, .yellow, .green, .cyan, .white]

    init(screenshot: UIImage) {
        self.screenshot = screenshot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Bug Report"
        setupNav()
        setupImageView()
        setupCanvas()
        setupToolbar()
    }

    // MARK: - Setup

    private func setupNav() {
        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()
            a.backgroundColor = UIColor(white: 0.08, alpha: 1)
            a.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController?.navigationBar.standardAppearance = a
            navigationController?.navigationBar.scrollEdgeAppearance = a
        }
        navigationController?.navigationBar.tintColor = PhantomTheme.shared.primaryColor

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        let shareBtn = UIBarButtonItem(title: "Export", style: .done, target: self, action: #selector(exportReport))
        shareBtn.tintColor = UIColor.Phantom.vibrantGreen
        navigationItem.rightBarButtonItem = shareBtn
    }

    private func setupImageView() {
        imageView.image = screenshot
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.strokeColor = selectedColor
        canvasView.lineWidth = brushWidth
        view.addSubview(canvasView)
        canvasView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            canvasView.topAnchor.constraint(equalTo: imageView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
    }

    private func setupToolbar() {
        toolbar.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        toolbar.layer.cornerRadius = 20
        if #available(iOS 13.0, *) { toolbar.layer.cornerCurve = .continuous }
        view.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 56),

            imageView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        toolbar.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
        ])

        // Color dots
        for (index, color) in colors.enumerated() {
            let dot = UIButton(type: .custom)
            dot.backgroundColor = color
            dot.layer.cornerRadius = 14
            dot.layer.borderWidth = index == 0 ? 3 : 0
            dot.layer.borderColor = UIColor.white.cgColor
            dot.tag = index
            dot.addTarget(self, action: #selector(colorSelected(_:)), for: .touchUpInside)
            stack.addArrangedSubview(dot)
            dot.widthAnchor.constraint(equalToConstant: 28).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        stack.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 24).isActive = true

        // Undo button
        let undoBtn = UIButton(type: .system)
        undoBtn.setTitle("Undo", for: .normal)
        undoBtn.setTitleColor(.white, for: .normal)
        undoBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        undoBtn.addTarget(self, action: #selector(undo), for: .touchUpInside)
        stack.addArrangedSubview(undoBtn)

        // Clear button
        let clearBtn = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            clearBtn.setImage(UIImage(systemName: "trash"), for: .normal)
            clearBtn.tintColor = UIColor.Phantom.vibrantRed
        } else {
            clearBtn.setTitle("Clear", for: .normal)
            clearBtn.setTitleColor(UIColor.Phantom.vibrantRed, for: .normal)
        }
        clearBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        clearBtn.addTarget(self, action: #selector(clearDrawing), for: .touchUpInside)
        stack.addArrangedSubview(clearBtn)
    }

    // MARK: - Actions

    @objc private func colorSelected(_ sender: UIButton) {
        // Reset all borders
        for case let dot as UIButton in (sender.superview?.subviews ?? []) {
            dot.layer.borderWidth = 0
        }
        sender.layer.borderWidth = 3
        sender.layer.borderColor = UIColor.white.cgColor
        selectedColor = colors[sender.tag]
        canvasView.strokeColor = selectedColor
    }

    @objc private func undo() {
        canvasView.undoLastStroke()
    }

    @objc private func clearDrawing() {
        canvasView.clearAll()
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func exportReport() {
        let annotatedImage = renderAnnotatedImage()
        let zipURL = PhantomBugReporter.shared.buildDiagnosticBundle(
            screenshot: screenshot,
            annotatedImage: canvasView.hasDrawing ? annotatedImage : nil
        )

        var items: [Any] = []
        if let zipURL = zipURL {
            items.append(zipURL)
        } else {
            // Fallback: share screenshot directly
            items.append(annotatedImage ?? screenshot)
        }

        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
            if let zipURL = zipURL {
                do {
                    try FileManager.default.removeItem(at: zipURL)
                } catch {
                    print("PhantomSwift Error: Failed to clean up zip file after export: \(error.localizedDescription)")
                }
            }
            self?.dismiss(animated: true)
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(activity, animated: true)
    }

    private func renderAnnotatedImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: imageView.bounds.size)
        return renderer.image { ctx in
            imageView.drawHierarchy(in: imageView.bounds, afterScreenUpdates: true)
            canvasView.drawHierarchy(in: canvasView.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - DrawingCanvasView

/// A transparent overlay view that supports freehand drawing with multiple strokes.
private final class DrawingCanvasView: UIView {

    var strokeColor: UIColor = .red
    var lineWidth: CGFloat = 3.0
    var hasDrawing: Bool { !strokes.isEmpty }

    private var strokes: [(color: UIColor, width: CGFloat, points: [CGPoint])] = []
    private var currentPoints: [CGPoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        currentPoints = [point]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        currentPoints.append(point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if currentPoints.count > 1 {
            strokes.append((color: strokeColor, width: lineWidth, points: currentPoints))
        }
        currentPoints = []
        setNeedsDisplay()
    }

    func undoLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        setNeedsDisplay()
    }

    func clearAll() {
        strokes.removeAll()
        currentPoints = []
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Draw completed strokes
        for stroke in strokes {
            drawStroke(ctx: ctx, points: stroke.points, color: stroke.color, width: stroke.width)
        }

        // Draw current stroke in progress
        if currentPoints.count > 1 {
            drawStroke(ctx: ctx, points: currentPoints, color: strokeColor, width: lineWidth)
        }
    }

    private func drawStroke(ctx: CGContext, points: [CGPoint], color: UIColor, width: CGFloat) {
        guard points.count > 1 else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.beginPath()
        ctx.move(to: points[0])
        for i in 1..<points.count {
            ctx.addLine(to: points[i])
        }
        ctx.strokePath()
    }
}
#endif
