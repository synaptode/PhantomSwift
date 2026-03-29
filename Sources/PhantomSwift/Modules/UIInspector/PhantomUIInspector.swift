#if DEBUG
import UIKit

/// Manages the UI inspection process.
internal final class PhantomUIInspector {
    internal static let shared = PhantomUIInspector()

    private var isInspecting = false
    private var overlayWindow: PhantomHUDWindow?
    private var selectionView: PhantomOverlayView?
    private var actionCard: UIInspectorActionCard?

    // MARK: - Inspection

    internal func startInspecting() {
        guard !isInspecting else { return }
        isInspecting = true

        if overlayWindow == nil {
            overlayWindow = PhantomHUDWindow(frame: UIScreen.main.bounds)
            overlayWindow?.windowLevel = .statusBar + 1
        }

        guard let overlayWindow else { return }
        selectionView = PhantomOverlayView(frame: overlayWindow.bounds)
        selectionView?.onViewSelected = { [weak self] view in
            self?.handleViewSelection(view)
        }
        if let selectionView { overlayWindow.addSubview(selectionView) }
        overlayWindow.makeKeyAndVisible()

        setupActionCard()
    }

    private func setupActionCard() {
        guard let overlayWindow else { return }
        let card = UIInspectorActionCard()
        actionCard = card
        card.backgroundColor = .clear
        card.alpha = 0
        card.onInspect = { [weak self] view in
            self?.showDetails(for: view)
        }
        card.onShowTree = { [weak self] view in
            self?.showTree(for: view)
        }
        card.onLiveEdit = { [weak self] view in
            self?.showLiveEdit(for: view)
        }
        card.onMeasure = { [weak self] in
            self?.startMeasurementMode()
        }
        overlayWindow.addSubview(card)

        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.bottomAnchor.constraint(equalTo: overlayWindow.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            card.centerXAnchor.constraint(equalTo: overlayWindow.centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 320),
            card.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    private func handleViewSelection(_ view: UIView) {
        actionCard?.show(for: view)
    }

    internal func stopInspecting() {
        isInspecting = false
        selectionView?.removeFromSuperview()
        actionCard?.removeFromSuperview()
        selectionView = nil
        actionCard = nil

        overlayWindow?.isHidden = true
        overlayWindow?.resignKey()
        overlayWindow = nil
    }

    // MARK: - Navigation

    private func showDetails(for view: UIView) {
        stopInspecting()
        let detailVC = ViewDetailVC(targetView: view)
        let nav = UINavigationController(rootViewController: detailVC)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    private func showLiveEdit(for view: UIView) {
        stopInspecting()
        let editVC = LiveEditVC(targetView: view)
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    private func showTree(for view: UIView) {
        stopInspecting()
        let root = UIApplication.shared.windows.first(where: { !($0 is PhantomHUDWindow) }) ?? view
        let treeVC = ViewHierarchyVC(rootView: root)
        let nav = UINavigationController(rootViewController: treeVC)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    // MARK: - Measurement Mode

    internal func startMeasurementMode() {
        // Dismiss action card but keep overlay window
        actionCard?.removeFromSuperview()
        actionCard = nil
        selectionView?.removeFromSuperview()
        selectionView = nil

        guard let overlayWindow else { return }
        PhantomMeasurementTool.shared.start(in: overlayWindow)
    }

    // MARK: - Constraint Conflict Overlay

    /// Highlights views in the app window that have known Auto Layout conflicts (red overlay).
    internal func showConflictHighlightOverlay() {
        guard let appWindow = UIApplication.shared.windows.first(where: { !($0 is PhantomHUDWindow) }) else { return }

        // Gather class names from captured conflicts
        let conflictClasses = Set(PhantomLayoutConflictDetector.shared.getAll()
            .compactMap { $0.viewClass })

        // Collect views in hierarchy matching conflict class names
        var conflictViews: [UIView] = []
        func find(_ v: UIView) {
            let name = String(describing: type(of: v))
            if conflictClasses.contains(name) { conflictViews.append(v) }
            v.subviews.forEach { find($0) }
        }
        find(appWindow)

        guard !conflictViews.isEmpty else { return }

        if overlayWindow == nil {
            overlayWindow = PhantomHUDWindow(frame: UIScreen.main.bounds)
            overlayWindow?.windowLevel = .statusBar + 1
            overlayWindow?.makeKeyAndVisible()
        }

        guard let overlayWindow else { return }
        let scanView = ConflictOverlayView(frame: overlayWindow.bounds, conflictViews: conflictViews)
        scanView.onDone = { [weak self] in
            scanView.removeFromSuperview()
            self?.stopInspecting()
        }
        overlayWindow.addSubview(scanView)
    }

    // MARK: - Global Debug Tools

    /// Toggle the design grid overlay (passthrough — does not stop inspection).
    internal func toggleGridOverlay() {
        PhantomGridOverlay.shared.toggle()
    }

    /// Show the grid configuration panel.
    internal func showGridConfig() {
        let gridVC = GridOverlayVC()
        let nav = UINavigationController(rootViewController: gridVC)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    /// Toggle the touch ripple visualizer.
    internal func toggleTouchVisualizer() {
        if PhantomTouchVisualizer.shared.isActive {
            PhantomTouchVisualizer.shared.stop()
        } else {
            PhantomTouchVisualizer.shared.start()
        }
    }

    /// Toggle the real-time FPS / CPU / Memory performance HUD.
    internal func togglePerfHUD() {
        PhantomFPSMonitor.shared.toggle()
    }

    /// Present the UserDefaults inspector (read/write/delete all keys).
    internal func showUserDefaultsInspector() {
        let vc = UserDefaultsInspectorVC()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    /// Present the environment override panel (dark mode, RTL, dynamic type, etc.).
    internal func showEnvironmentOverride() {
        let vc = EnvironmentOverrideVC()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        present(nav)
    }

    /// Present the interactive hit-test inspector on top of the current app state.
    internal func showHitTestInspector() {
        guard let appWindow = UIApplication.shared.windows
            .first(where: { !($0 is PhantomHUDWindow) && $0.rootViewController != nil }) else { return }
        let screenshot = UIView.captureAppWindow()
        guard let ss = screenshot else { return }
        stopInspecting()
        let vc = HitTestInspectorVC(screenshot: ss, appWindow: appWindow)
        let root = appWindow.rootViewController
        var top = root
        while let p = top?.presentedViewController { top = p }
        top?.present(vc, animated: false)
    }

    // MARK: - Helpers

    private func present(_ vc: UIViewController) {
        if let root = UIApplication.shared.windows
            .first(where: { !($0 is PhantomHUDWindow) && $0.rootViewController != nil })?.rootViewController {
            var top = root
            while let p = top.presentedViewController { top = p }
            top.present(vc, animated: true)
        }
    }
}

// MARK: - ConflictOverlayView

/// Red dashed overlays on views that have Auto Layout conflicts.
private final class ConflictOverlayView: UIView {

    internal var onDone: (() -> Void)?

    init(frame: CGRect, conflictViews: [UIView]) {
        super.init(frame: frame)
        setup(conflictViews: conflictViews)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(conflictViews: [UIView]) {
        backgroundColor = UIColor.black.withAlphaComponent(0.15)

        conflictViews.forEach { view in
            let rect = view.convert(view.bounds, to: self)
            guard rect.width > 0, rect.height > 0 else { return }

            // Red pulsing fill
            let highlight = UIView(frame: rect)
            highlight.backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.15)
            highlight.layer.borderColor = UIColor.Phantom.vibrantRed.cgColor
            highlight.layer.borderWidth = 2
            highlight.layer.cornerRadius = 3
            addSubview(highlight)

            // Badge
            let badge = UILabel()
            badge.text = " ⚠ "
            badge.font = .systemFont(ofSize: 9, weight: .black)
            badge.textColor = UIColor.Phantom.vibrantRed
            badge.backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.2)
            badge.layer.cornerRadius = 5
            badge.layer.masksToBounds = true
            badge.sizeToFit()
            badge.frame.origin = CGPoint(x: rect.minX + 2, y: rect.minY + 2)
            addSubview(badge)

            // Pulse animation
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.duration = 0.8
            pulse.fromValue = 0.4
            pulse.toValue = 1.0
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            highlight.layer.add(pulse, forKey: "conflictPulse")
        }

        // Done button
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("✕ Close", for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .black)
        doneBtn.tintColor = .white
        doneBtn.backgroundColor = UIColor.Phantom.vibrantRed
        doneBtn.layer.cornerRadius = 16
        doneBtn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.addTarget(self, action: #selector(handleDone), for: .touchUpInside)
        addSubview(doneBtn)

        // Info label
        let infoLabel = UILabel()
        infoLabel.text = "\(conflictViews.count) constraint conflict\(conflictViews.count == 1 ? "" : "s") detected"
        infoLabel.font = .systemFont(ofSize: 10, weight: .bold)
        infoLabel.textColor = UIColor.Phantom.vibrantRed
        infoLabel.textAlignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoLabel)

        NSLayoutConstraint.activate([
            doneBtn.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            doneBtn.centerXAnchor.constraint(equalTo: centerXAnchor),
            infoLabel.topAnchor.constraint(equalTo: doneBtn.bottomAnchor, constant: 8),
            infoLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @objc private func handleDone() { onDone?() }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Absorb touches – don't pass through
    }
}

// MARK: - Enhanced Overlay View

/// Intercepts touches to find the deepest subview under the cursor.
/// Shows cross-hair ruler, coordinate readout, pulsing highlight, and a stop button.
internal final class PhantomOverlayView: UIView {
    internal var onViewSelected: ((UIView) -> Void)?

    private let highlightLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()
    private let coordLabel = UILabel()
    private let sizeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.25)

        // Highlight layer
        highlightLayer.strokeColor = UIColor.Phantom.neonAzure.cgColor
        highlightLayer.lineWidth = 2
        highlightLayer.fillColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.08).cgColor
        highlightLayer.lineDashPattern = [6, 3]
        layer.addSublayer(highlightLayer)

        // Cross-hair rulers
        crosshairLayer.strokeColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.4).cgColor
        crosshairLayer.lineWidth = 0.5
        crosshairLayer.lineDashPattern = [4, 4]
        crosshairLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(crosshairLayer)

        // Coordinate readout — positioned via frame in drawHighlight, NOT auto layout
        coordLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        coordLabel.textColor = UIColor.Phantom.neonAzure
        coordLabel.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.9)
        coordLabel.textAlignment = .center
        coordLabel.layer.cornerRadius = 6
        coordLabel.layer.masksToBounds = true
        coordLabel.alpha = 0
        addSubview(coordLabel)

        // Size readout — positioned via frame in drawHighlight, NOT auto layout
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        sizeLabel.textColor = UIColor.Phantom.vibrantGreen
        sizeLabel.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.9)
        sizeLabel.textAlignment = .center
        sizeLabel.layer.cornerRadius = 6
        sizeLabel.layer.masksToBounds = true
        sizeLabel.alpha = 0
        addSubview(sizeLabel)

        // Stop button
        let stopButton = UIButton(type: .system)
        stopButton.backgroundColor = UIColor.Phantom.vibrantRed
        stopButton.tintColor = .white
        stopButton.layer.cornerRadius = 18
        if #available(iOS 13.0, *) {
            stopButton.layer.cornerCurve = .continuous
        }
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stopButton)

        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            let img = UIImage(systemName: "xmark", withConfiguration: config)
            stopButton.setImage(img, for: .normal)
            stopButton.setTitle("  STOP", for: .normal)
        } else {
            stopButton.setTitle("STOP INSPECTOR", for: .normal)
        }
        stopButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .black)
        stopButton.addTarget(self, action: #selector(handleStop), for: .touchUpInside)

        PhantomTheme.shared.applyPremiumShadow(to: stopButton.layer)

        // Hint label
        let hintLabel = UILabel()
        hintLabel.text = "TAP ANY VIEW TO INSPECT"
        hintLabel.font = .systemFont(ofSize: 9, weight: .black)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            stopButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            stopButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 100),
            stopButton.heightAnchor.constraint(equalToConstant: 36),

            hintLabel.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

        ])
    }

    @objc private func handleStop() {
        PhantomUIInspector.shared.stopInspecting()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        let windows = UIApplication.shared.windows
        // Prefer a window that (a) is not our HUD, (b) has a rootViewController (i.e. the real app window)
        let appWindow = windows.first(where: { !($0 is PhantomHUDWindow) && $0.rootViewController != nil && $0.isKeyWindow })
            ?? windows.first(where: { !($0 is PhantomHUDWindow) && $0.rootViewController != nil })
        if let appWindow = appWindow {
            let convertedPoint = self.convert(point, to: appWindow)
            let foundView = findDeepestView(at: convertedPoint, in: appWindow)

            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            drawHighlight(for: foundView)
            drawCrosshair(for: foundView)
            onViewSelected?(foundView)
        }
    }

    /// Finds the deepest, smallest view that contains `point`.
    /// Combines manual subview traversal (ignores `isUserInteractionEnabled`)
    /// with UIKit `hitTest` (respects SwiftUI hosting view overrides).
    private func findDeepestView(at point: CGPoint, in rootView: UIView) -> UIView {
        var best: UIView = rootView
        var bestDepth: Int = 0
        var bestArea: CGFloat = .greatestFiniteMagnitude

        func consider(_ view: UIView, depth: Int) {
            let area = view.bounds.width * view.bounds.height
            guard area >= 1 else { return }
            if depth > bestDepth || (depth == bestDepth && area < bestArea) {
                best = view
                bestDepth = depth
                bestArea = area
            }
        }

        // Pass 1: walk every subview regardless of isUserInteractionEnabled
        func traverse(_ view: UIView, parentPoint: CGPoint, depth: Int) {
            for subview in view.subviews {
                if subview is PhantomOverlayView { continue }
                if let w = subview.window, w is PhantomHUDWindow { continue }

                let localPoint = view.convert(parentPoint, to: subview)
                guard subview.point(inside: localPoint, with: nil),
                      !subview.isHidden, subview.alpha > 0.01 else { continue }

                consider(subview, depth: depth)
                traverse(subview, parentPoint: localPoint, depth: depth + 1)
            }
        }

        traverse(rootView, parentPoint: point, depth: 1)

        // Pass 2: UIKit hitTest — SwiftUI hosting views override this to
        // return deeper internal views our subview walk may miss.
        if let hitView = rootView.hitTest(point, with: nil),
           hitView !== rootView {
            var hitDepth = 0
            var v: UIView? = hitView
            while let cur = v, cur !== rootView { hitDepth += 1; v = cur.superview }

            consider(hitView, depth: hitDepth)

            // Continue traversal from the hitTest result
            let hitPoint = rootView.convert(point, to: hitView)
            traverse(hitView, parentPoint: hitPoint, depth: hitDepth + 1)
        }

        return best
    }

    private func drawHighlight(for view: UIView) {
        let rect = view.convert(view.bounds, to: self)
        let rounded = UIBezierPath(roundedRect: rect, cornerRadius: 2)
        highlightLayer.path = rounded.cgPath

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.duration = 0.6; pulse.fromValue = 0.5; pulse.toValue = 1.0
        pulse.autoreverses = true; pulse.repeatCount = .infinity
        highlightLayer.add(pulse, forKey: "pulse")

        // -- Coordinate label (top-left of the selected view) --
        coordLabel.text = "  \(Int(rect.origin.x)), \(Int(rect.origin.y))  "
        coordLabel.sizeToFit()
        let coordW = coordLabel.frame.width + 14
        let coordH: CGFloat = 22
        var coordY = rect.minY - coordH - 4
        // Flip below if too close to top
        if coordY < safeAreaInsets.top + 50 { coordY = rect.maxY + 4 }
        var coordX = rect.minX
        // Clamp within screen width
        coordX = min(coordX, bounds.width - coordW - 4)
        coordX = max(coordX, 4)
        coordLabel.frame = CGRect(x: coordX, y: coordY, width: coordW, height: coordH)
        UIView.animate(withDuration: 0.2) { self.coordLabel.alpha = 1 }

        // -- Size label (bottom-right of the selected view) --
        sizeLabel.text = "  \(Int(rect.width)) × \(Int(rect.height))  "
        sizeLabel.sizeToFit()
        let sizeW = sizeLabel.frame.width + 14
        let sizeH: CGFloat = 20
        var sizeX = rect.maxX - sizeW
        sizeX = min(sizeX, bounds.width - sizeW - 4)
        sizeX = max(sizeX, 4)
        var sizeY = rect.maxY + 4
        // Clamp within screen
        if sizeY + sizeH > bounds.height - safeAreaInsets.bottom - 8 {
            sizeY = rect.minY - sizeH - 4
        }
        sizeLabel.frame = CGRect(x: sizeX, y: sizeY, width: sizeW, height: sizeH)
        UIView.animate(withDuration: 0.2) { self.sizeLabel.alpha = 1 }
    }

    private func drawCrosshair(for view: UIView) {
        let rect = view.convert(view.bounds, to: self)
        let path = UIBezierPath()

        // Horizontal ruler through center
        let cy = rect.midY
        path.move(to: CGPoint(x: 0, y: cy))
        path.addLine(to: CGPoint(x: bounds.width, y: cy))

        // Vertical ruler through center
        let cx = rect.midX
        path.move(to: CGPoint(x: cx, y: 0))
        path.addLine(to: CGPoint(x: cx, y: bounds.height))

        crosshairLayer.path = path.cgPath
    }
}
#endif
