#if DEBUG
import UIKit

// MARK: - HitTest Entry Model

private struct HitTestEntry {
    let view: UIView
    let depth: Int
    let className: String
    let localPoint: CGPoint
    let passesHidden: Bool
    let passesAlpha: Bool
    let passesInteraction: Bool
    let passesContains: Bool
    let isWinner: Bool

    var passes: Bool { passesHidden && passesAlpha && passesInteraction && passesContains }

    var failReason: String? {
        if !passesHidden    { return "isHidden = true" }
        if !passesAlpha     { return "alpha ≤ 0.01" }
        if !passesInteraction { return "isUserInteractionEnabled = false" }
        if !passesContains  { return "point outside bounds" }
        return nil
    }
}

// MARK: - HitTestInspectorVC

/// Interactive full-screen hit-test inspector.
/// Shows the app screenshot as background; the user taps anywhere to trace which view
/// would receive that touch, plus the full ancestor chain from winner → window.
internal final class HitTestInspectorVC: UIViewController {

    // MARK: - Private State

    private let screenshot:       UIImage
    private let appWindow:        UIView
    private var hitEntries:       [HitTestEntry]  = []
    private var highlightViews:   [UIView]        = []
    private var lastTapPoint:     CGPoint?

    // MARK: - Subviews

    private let bgImageView       = UIImageView()
    private let hintLabel         = UILabel()
    private let crosshairView     = HitCrosshairView()
    private let resultPanel       = UIView()
    private let resultTable       = UITableView(frame: .zero, style: .plain)
    private let panelHandle       = UIView()
    private var panelBottomConstraint: NSLayoutConstraint!
    private let highlightOverlay  = UIView()

    // MARK: - Panel State

    private enum PanelState { case collapsed, expanded }
    private var panelState: PanelState = .collapsed
    private let panelCollapsedY: CGFloat = UIScreen.main.bounds.height - 96
    private let panelExpandedY:  CGFloat = UIScreen.main.bounds.height * 0.45

    // MARK: - Init

    internal init(screenshot: UIImage, appWindow: UIView) {
        self.screenshot = screenshot
        self.appWindow  = appWindow
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupHighlightOverlay()
        setupHintLabel()
        setupCrosshair()
        setupResultPanel()
        setupGestures()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupBackground() {
        bgImageView.image       = screenshot
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.frame       = view.bounds
        bgImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(bgImageView)

        // Dark scrim for readability
        let scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrim)
    }

    private func setupHighlightOverlay() {
        highlightOverlay.frame = view.bounds
        highlightOverlay.backgroundColor = .clear
        highlightOverlay.isUserInteractionEnabled = false
        highlightOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(highlightOverlay)
    }

    private func setupHintLabel() {
        hintLabel.text            = "Tap anywhere to trace the hit-test chain"
        hintLabel.font            = .systemFont(ofSize: 13, weight: .black)
        hintLabel.textColor       = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment   = .center
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hintLabel.layer.cornerRadius   = 14
        hintLabel.layer.masksToBounds  = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        let closeBtn = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        } else {
            closeBtn.setTitle("✕", for: .normal)
        }
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        closeBtn.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.heightAnchor.constraint(equalToConstant: 38),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 60),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -60),

            closeBtn.centerYAnchor.constraint(equalTo: hintLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupCrosshair() {
        crosshairView.alpha = 0
        crosshairView.isUserInteractionEnabled = false
        crosshairView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(crosshairView)
    }

    private func setupResultPanel() {
        resultPanel.backgroundColor   = PhantomTheme.shared.backgroundColor
        resultPanel.layer.cornerRadius = 20
        resultPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        resultPanel.layer.shadowColor   = UIColor.black.cgColor
        resultPanel.layer.shadowOpacity = 0.5
        resultPanel.layer.shadowRadius  = 16
        resultPanel.layer.shadowOffset  = CGSize(width: 0, height: -4)
        resultPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultPanel)

        panelBottomConstraint = resultPanel.topAnchor.constraint(
            equalTo: view.bottomAnchor, constant: -96)
        NSLayoutConstraint.activate([
            resultPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resultPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 20),
            panelBottomConstraint
        ])

        // Handle
        panelHandle.backgroundColor    = UIColor.white.withAlphaComponent(0.2)
        panelHandle.layer.cornerRadius = 2
        panelHandle.translatesAutoresizingMaskIntoConstraints = false
        resultPanel.addSubview(panelHandle)

        // Table
        resultTable.backgroundColor = .clear
        resultTable.separatorColor  = UIColor.white.withAlphaComponent(0.07)
        resultTable.dataSource = self
        resultTable.delegate   = self
        resultTable.register(HitTestRowCell.self, forCellReuseIdentifier: "HitTestRowCell")
        resultTable.translatesAutoresizingMaskIntoConstraints = false
        resultPanel.addSubview(resultTable)

        NSLayoutConstraint.activate([
            panelHandle.topAnchor.constraint(equalTo: resultPanel.topAnchor, constant: 10),
            panelHandle.centerXAnchor.constraint(equalTo: resultPanel.centerXAnchor),
            panelHandle.widthAnchor.constraint(equalToConstant: 36),
            panelHandle.heightAnchor.constraint(equalToConstant: 4),

            resultTable.topAnchor.constraint(equalTo: panelHandle.bottomAnchor, constant: 8),
            resultTable.leadingAnchor.constraint(equalTo: resultPanel.leadingAnchor),
            resultTable.trailingAnchor.constraint(equalTo: resultPanel.trailingAnchor),
            resultTable.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Panel drag
        let panelPan = UIPanGestureRecognizer(target: self, action: #selector(handlePanelPan(_:)))
        resultPanel.addGestureRecognizer(panelPan)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
    }

    // MARK: - Hit Test Logic

    /// Runs the UIKit hit-test algorithm on the app window and builds the result chain.
    private func performHitTest(at screenPoint: CGPoint) {
        hitEntries.removeAll()
        clearHighlights()

        let winner = traceHitTest(view: appWindow, screenPoint: screenPoint)
        buildAncestorChain(from: winner, screenPoint: screenPoint)
        resultTable.reloadData()
        updateHighlights()
        updateHintLabel(winner: winner)
    }

    /// Recursively walks the hierarchy to find the deepest view that passes hitTest.
    @discardableResult
    private func traceHitTest(view: UIView, screenPoint: CGPoint) -> UIView? {
        let className = String(describing: type(of: view))
        guard !className.hasPrefix("Phantom"), !className.hasPrefix("_") else { return nil }

        let localPt           = view.convert(screenPoint, from: nil)
        let passesHidden      = !view.isHidden
        let passesAlpha       = view.alpha > 0.01
        let passesInteraction = view.isUserInteractionEnabled
        let passesContains    = view.point(inside: localPt, with: nil)

        guard passesHidden && passesAlpha && passesInteraction && passesContains else { return nil }

        // Search deepest match among subviews (front-to-back)
        var deepest: UIView? = nil
        for subview in view.subviews.reversed() {
            if let hit = traceHitTest(view: subview, screenPoint: screenPoint) {
                deepest = hit
                break
            }
        }

        return deepest ?? view
    }

    /// Builds the ancestor chain from the winner up to the root view.
    private func buildAncestorChain(from winner: UIView?, screenPoint: CGPoint) {
        guard let winner  else { return }
        var current: UIView? = winner
        var depth = 0
        while let v = current {
            let className = String(describing: type(of: v))
            guard !className.hasPrefix("Phantom") else { current = v.superview; depth += 1; continue }

            let localPt           = v.convert(screenPoint, from: nil)
            let passesHidden      = !v.isHidden
            let passesAlpha       = v.alpha > 0.01
            let passesInteraction = v.isUserInteractionEnabled
            let passesContains    = v.point(inside: localPt, with: nil)

            hitEntries.append(HitTestEntry(
                view: v,
                depth: depth,
                className: className,
                localPoint: localPt,
                passesHidden: passesHidden,
                passesAlpha: passesAlpha,
                passesInteraction: passesInteraction,
                passesContains: passesContains,
                isWinner: v === winner
            ))
            current = v.superview
            depth  += 1
        }
    }

    // MARK: - Highlights

    private func updateHighlights() {
        clearHighlights()
        for (idx, entry) in hitEntries.enumerated() {
            let rect = entry.view.convert(entry.view.bounds, to: nil)
            guard rect.width > 0, rect.height > 0 else { continue }

            let overlay = UIView(frame: rect)
            if entry.isWinner {
                overlay.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.25)
                overlay.layer.borderColor = UIColor.Phantom.vibrantGreen.cgColor
                overlay.layer.borderWidth = 2
            } else {
                let alpha = max(0.06, 0.22 - CGFloat(idx) * 0.04)
                overlay.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(alpha)
                overlay.layer.borderColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.3).cgColor
                overlay.layer.borderWidth = 1
            }
            overlay.layer.cornerRadius = 3
            overlay.isUserInteractionEnabled = false
            highlightOverlay.addSubview(overlay)
            highlightViews.append(overlay)
        }
    }

    private func clearHighlights() {
        highlightViews.forEach { $0.removeFromSuperview() }
        highlightViews.removeAll()
    }

    // MARK: - Panel Transitions

    private func setPanel(state: PanelState, animated: Bool = true) {
        panelState = state
        let top: CGFloat
        switch state {
        case .collapsed: top = -96
        case .expanded:  top = -(view.bounds.height - panelExpandedY)
        }
        panelBottomConstraint.constant = top
        guard animated else { view.layoutIfNeeded(); return }
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateHintLabel(winner: UIView?) {
        if let w = winner {
            hintLabel.text = "✓ \(String(describing: type(of: w)))"
            hintLabel.textColor = UIColor.Phantom.vibrantGreen
        } else {
            hintLabel.text = "✗ No view responds to this touch"
            hintLabel.textColor = UIColor.Phantom.vibrantRed
        }
    }

    // MARK: - Crosshair

    private func moveCrosshair(to pt: CGPoint) {
        crosshairView.frame = CGRect(x: pt.x - 40, y: pt.y - 40, width: 80, height: 80)
        crosshairView.alpha = 1
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        let pt = gr.location(in: view)
        lastTapPoint = pt
        moveCrosshair(to: pt)
        performHitTest(at: pt)

        if panelState == .collapsed {
            setPanel(state: .expanded)
        }
    }

    @objc private func handlePanelPan(_ gr: UIPanGestureRecognizer) {
        let translation = gr.translation(in: view)
        let velocity    = gr.velocity(in: view)

        if gr.state == .changed {
            let base: CGFloat
            switch panelState {
            case .collapsed: base = -96
            case .expanded:  base = -(view.bounds.height - panelExpandedY)
            }
            let newTop = base + translation.y
            panelBottomConstraint.constant = max(-(view.bounds.height - 100), min(-60, newTop))
            view.layoutIfNeeded()
        } else if gr.state == .ended || gr.state == .cancelled {
            setPanel(state: velocity.y > 0 ? .collapsed : .expanded)
        }
    }

    @objc private func handleClose() {
        clearHighlights()
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource, Delegate

extension HitTestInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        hitEntries.isEmpty ? 1 : hitEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HitTestRowCell", for: indexPath) as! HitTestRowCell
        if hitEntries.isEmpty {
            cell.configureEmpty()
        } else {
            cell.configure(with: hitEntries[indexPath.row])
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 72 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < hitEntries.count else { return }
        let entry = hitEntries[indexPath.row]
        // Flash the corresponding highlight
        if let hl = highlightViews[safe: indexPath.row] {
            UIView.animate(withDuration: 0.12, animations: { hl.alpha = 0 }) { _ in
                UIView.animate(withDuration: 0.12) { hl.alpha = 1 }
            }
        }
        // Show a detail VC for that view
        let detail = ViewDetailVC(targetView: entry.view)
        let nav = UINavigationController(rootViewController: detail)
        nav.modalPresentationStyle = .overFullScreen
        present(nav, animated: true)
    }
}

// MARK: - HitTestRowCell

private final class HitTestRowCell: UITableViewCell {

    private let winnerBadge = UILabel()
    private let depthLine   = UIView()
    private let classLabel  = UILabel()
    private let frameLabel  = UILabel()
    private let failLabel   = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .default

        depthLine.layer.cornerRadius = 2
        depthLine.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(depthLine)

        winnerBadge.font              = .systemFont(ofSize: 9, weight: .black)
        winnerBadge.layer.cornerRadius = 6
        winnerBadge.layer.masksToBounds = true
        winnerBadge.textAlignment      = .center
        winnerBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(winnerBadge)

        classLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        classLabel.textColor = .white
        classLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(classLabel)

        frameLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        frameLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        frameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(frameLabel)

        failLabel.font      = UIFont.systemFont(ofSize: 10, weight: .bold)
        failLabel.textColor = UIColor.Phantom.vibrantRed
        failLabel.numberOfLines = 0
        failLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(failLabel)

        NSLayoutConstraint.activate([
            depthLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            depthLine.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            depthLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            depthLine.widthAnchor.constraint(equalToConstant: 3),

            classLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            classLabel.leadingAnchor.constraint(equalTo: depthLine.trailingAnchor, constant: 12),
            classLabel.trailingAnchor.constraint(equalTo: winnerBadge.leadingAnchor, constant: -8),

            winnerBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            winnerBadge.centerYAnchor.constraint(equalTo: classLabel.centerYAnchor),
            winnerBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            winnerBadge.heightAnchor.constraint(equalToConstant: 20),

            frameLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 3),
            frameLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            frameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            failLabel.topAnchor.constraint(equalTo: frameLabel.bottomAnchor, constant: 2),
            failLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            failLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            failLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: HitTestEntry) {
        let indent = String(repeating: "  ", count: entry.depth)
        classLabel.text = "\(indent)\(entry.className)"

        let f = entry.view.frame
        frameLabel.text = String(format: "%.0f, %.0f  %@%.0f × %.0f",
                                  f.origin.x, f.origin.y,
                                  entry.depth == 0 ? "" : "↳ ",
                                  f.width, f.height)

        if entry.isWinner {
            depthLine.backgroundColor  = UIColor.Phantom.vibrantGreen
            winnerBadge.text           = "  HIT  "
            winnerBadge.textColor      = UIColor.Phantom.vibrantGreen
            winnerBadge.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.15)
            failLabel.text = nil
        } else if let reason = entry.failReason {
            depthLine.backgroundColor  = UIColor.Phantom.vibrantRed.withAlphaComponent(0.4)
            winnerBadge.text           = "  FAIL  "
            winnerBadge.textColor      = UIColor.Phantom.vibrantRed
            winnerBadge.backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.12)
            failLabel.text = "⛔ \(reason)"
        } else {
            depthLine.backgroundColor  = UIColor.Phantom.neonAzure.withAlphaComponent(0.5)
            winnerBadge.text           = "  PASS  "
            winnerBadge.textColor      = UIColor.Phantom.neonAzure
            winnerBadge.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.1)
            failLabel.text = nil
        }
    }

    func configureEmpty() {
        classLabel.text    = "Tap the screen above to inspect"
        classLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        frameLabel.text    = nil
        failLabel.text     = nil
        winnerBadge.text   = nil
        depthLine.backgroundColor = UIColor.white.withAlphaComponent(0.1)
    }
}

// MARK: - HitCrosshairView

private final class HitCrosshairView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cx = rect.midX, cy = rect.midY, r: CGFloat = 6, gap: CGFloat = 4

        ctx.setStrokeColor(UIColor.Phantom.vibrantGreen.cgColor)
        ctx.setLineWidth(1.5)

        // Horizontal arms
        ctx.move(to: CGPoint(x: 0, y: cy)); ctx.addLine(to: CGPoint(x: cx - r - gap, y: cy))
        ctx.move(to: CGPoint(x: cx + r + gap, y: cy)); ctx.addLine(to: CGPoint(x: rect.maxX, y: cy))
        // Vertical arms
        ctx.move(to: CGPoint(x: cx, y: 0)); ctx.addLine(to: CGPoint(x: cx, y: cy - r - gap))
        ctx.move(to: CGPoint(x: cx, y: cy + r + gap)); ctx.addLine(to: CGPoint(x: cx, y: rect.maxY))
        ctx.strokePath()

        // Center ring
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.strokePath()
    }
}

// MARK: - safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#endif
