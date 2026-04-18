#if DEBUG
import UIKit

/// Measurement mode overlay: tap two views to visualize the pixel distance between them.
/// Shows horizontal, vertical, and diagonal spacing with ruler annotations.
internal final class PhantomMeasurementTool {

    internal static let shared = PhantomMeasurementTool()
    private init() {}

    private var overlayWindow: PhantomHUDWindow?
    private var measureView: MeasurementOverlayView?
    private var isActive = false

    internal func start(in window: PhantomHUDWindow) {
        guard !isActive else { return }
        isActive = true
        overlayWindow = window

        let mv = MeasurementOverlayView(frame: window.bounds)
        mv.onDone = { [weak self] in self?.stop() }
        window.addSubview(mv)
        measureView = mv
    }

    internal func stop() {
        isActive = false
        measureView?.removeFromSuperview()
        measureView = nil
    }
}

// MARK: - MeasurementOverlayView

internal final class MeasurementOverlayView: UIView {

    internal var onDone: (() -> Void)?

    private var firstView: UIView?
    private var secondView: UIView?
    private var firstRect: CGRect = .zero
    private var secondRect: CGRect = .zero

    private let canvas = UIView()
    private let hintLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let measureLayer = CAShapeLayer()
    private var annotationLabels: [UILabel] = []

    private var selectionHighlights: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.2)

        // Measure drawing layer
        measureLayer.fillColor = UIColor.clear.cgColor
        measureLayer.strokeColor = UIColor.Phantom.neonAzure.cgColor
        measureLayer.lineWidth = 1.5
        measureLayer.lineDashPattern = [4, 3]
        layer.addSublayer(measureLayer)

        // Hint
        hintLabel.text = "TAP VIEW 1"
        hintLabel.font = .systemFont(ofSize: 11, weight: .black)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment = .center
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        hintLabel.layer.cornerRadius = 8
        hintLabel.layer.masksToBounds = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        // Done button
        doneButton.setTitle("✕ Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .black)
        doneButton.tintColor = .white
        doneButton.backgroundColor = UIColor.Phantom.vibrantRed
        doneButton.layer.cornerRadius = 16
        doneButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(handleDone), for: .touchUpInside)
        addSubview(doneButton)

        // Clear button
        clearButton.setTitle("↺ Clear", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .bold)
        clearButton.tintColor = UIColor.white.withAlphaComponent(0.6)
        clearButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        clearButton.layer.cornerRadius = 12
        clearButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearSelection), for: .touchUpInside)
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            doneButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hintLabel.topAnchor.constraint(equalTo: doneButton.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    // MARK: - Touch Handling

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        guard let appWindow = PhantomPresentationResolver.activeHostWindow() else { return }
        let converted = convert(point, to: appWindow)
        guard let hit = appWindow.hitTest(converted, with: nil),
              hit !== appWindow else { return }

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()

        if firstView == nil {
            firstView = hit
            firstRect = hit.convert(hit.bounds, to: self)
            drawHighlight(for: firstRect, color: UIColor.Phantom.neonAzure, tag: "A")
            hintLabel.text = "TAP VIEW 2"
        } else if secondView == nil {
            secondView = hit
            secondRect = hit.convert(hit.bounds, to: self)
            drawHighlight(for: secondRect, color: UIColor.Phantom.vibrantOrange, tag: "B")
            drawMeasurements()
            hintLabel.text = "↺ Clear to remeasure"
        }
    }

    // MARK: - Highlight

    private func drawHighlight(for rect: CGRect, color: UIColor, tag: String) {
        let highlight = UIView(frame: rect)
        highlight.backgroundColor = color.withAlphaComponent(0.12)
        highlight.layer.borderColor = color.cgColor
        highlight.layer.borderWidth = 2
        highlight.layer.cornerRadius = 2
        insertSubview(highlight, belowSubview: doneButton)
        selectionHighlights.append(highlight)

        let badge = UILabel()
        badge.text = "  \(tag)  "
        badge.font = .systemFont(ofSize: 9, weight: .black)
        badge.textColor = color
        badge.backgroundColor = color.withAlphaComponent(0.25)
        badge.layer.cornerRadius = 6
        badge.layer.masksToBounds = true
        badge.sizeToFit()
        badge.frame.size.width += 8
        badge.frame.origin = CGPoint(x: rect.minX + 4, y: rect.minY + 4)
        insertSubview(badge, belowSubview: doneButton)
        selectionHighlights.append(badge)
    }

    // MARK: - Measurement Drawing

    private func drawMeasurements() {
        clearAnnotations()

        let r1 = firstRect
        let r2 = secondRect

        let path = UIBezierPath()

        // Horizontal distance line (between closest horizontal edges)
        let hGap: CGFloat
        let lineY = (min(r1.midY, r2.midY) + max(r1.midY, r2.midY)) / 2

        if r1.maxX <= r2.minX {
            // r1 is left of r2
            let startX = r1.maxX
            let endX   = r2.minX
            hGap = endX - startX
            drawArrowLine(in: path, from: CGPoint(x: startX, y: lineY), to: CGPoint(x: endX, y: lineY))
            addAnnotation(String(format: "%.0f pt", hGap),
                          at: CGPoint(x: (startX + endX) / 2, y: lineY - 14),
                          color: UIColor.Phantom.neonAzure)
        } else if r2.maxX <= r1.minX {
            let startX = r2.maxX
            let endX   = r1.minX
            hGap = endX - startX
            drawArrowLine(in: path, from: CGPoint(x: startX, y: lineY), to: CGPoint(x: endX, y: lineY))
            addAnnotation(String(format: "%.0f pt", hGap),
                          at: CGPoint(x: (startX + endX) / 2, y: lineY - 14),
                          color: UIColor.Phantom.neonAzure)
        }

        // Vertical distance line (between closest vertical edges)
        let vLineX = (min(r1.midX, r2.midX) + max(r1.midX, r2.midX)) / 2
        if r1.maxY <= r2.minY {
            let startY = r1.maxY
            let endY   = r2.minY
            let vGap = endY - startY
            drawArrowLine(in: path, from: CGPoint(x: vLineX, y: startY), to: CGPoint(x: vLineX, y: endY))
            addAnnotation(String(format: "%.0f pt", vGap),
                          at: CGPoint(x: vLineX + 6, y: (startY + endY) / 2),
                          color: UIColor.Phantom.vibrantOrange)
        } else if r2.maxY <= r1.minY {
            let startY = r2.maxY
            let endY   = r1.minY
            let vGap = endY - startY
            drawArrowLine(in: path, from: CGPoint(x: vLineX, y: startY), to: CGPoint(x: vLineX, y: endY))
            addAnnotation(String(format: "%.0f pt", vGap),
                          at: CGPoint(x: vLineX + 6, y: (startY + endY) / 2),
                          color: UIColor.Phantom.vibrantOrange)
        }

        // Center-to-center diagonal
        let c1 = CGPoint(x: r1.midX, y: r1.midY)
        let c2 = CGPoint(x: r2.midX, y: r2.midY)
        let diag = hypot(c2.x - c1.x, c2.y - c1.y)
        path.move(to: c1)
        path.addLine(to: c2)
        addAnnotation(String(format: "⤢ %.0f pt", diag),
                      at: CGPoint(x: (c1.x + c2.x) / 2, y: (c1.y + c2.y) / 2 - 14),
                      color: UIColor.Phantom.vibrantGreen)

        // Size annotations
        addAnnotation(String(format: "%.0f × %.0f", r1.width, r1.height),
                      at: CGPoint(x: r1.midX, y: r1.maxY + 4),
                      color: UIColor.Phantom.neonAzure.withAlphaComponent(0.8))
        addAnnotation(String(format: "%.0f × %.0f", r2.width, r2.height),
                      at: CGPoint(x: r2.midX, y: r2.maxY + 4),
                      color: UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8))

        measureLayer.path = path.cgPath
    }

    private func drawArrowLine(in path: UIBezierPath, from start: CGPoint, to end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)

        // Tick marks at ends
        let dx = end.x - start.x
        let dy = end.y - start.y
        let isHorizontal = abs(dx) > abs(dy)

        if isHorizontal {
            path.move(to: CGPoint(x: start.x, y: start.y - 5))
            path.addLine(to: CGPoint(x: start.x, y: start.y + 5))
            path.move(to: CGPoint(x: end.x, y: end.y - 5))
            path.addLine(to: CGPoint(x: end.x, y: end.y + 5))
        } else {
            path.move(to: CGPoint(x: start.x - 5, y: start.y))
            path.addLine(to: CGPoint(x: start.x + 5, y: start.y))
            path.move(to: CGPoint(x: end.x - 5, y: end.y))
            path.addLine(to: CGPoint(x: end.x + 5, y: end.y))
        }
    }

    private func addAnnotation(_ text: String, at point: CGPoint, color: UIColor) {
        let label = UILabel()
        label.text = "  \(text)  "
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        label.textColor = color
        label.backgroundColor = PhantomTheme.shared.backgroundColor.withAlphaComponent(0.85)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.sizeToFit()
        label.center = point
        insertSubview(label, belowSubview: doneButton)
        annotationLabels.append(label)
    }

    // MARK: - Clear

    private func clearAnnotations() {
        annotationLabels.forEach { $0.removeFromSuperview() }
        annotationLabels.removeAll()
        measureLayer.path = nil
    }

    @objc private func clearSelection() {
        firstView = nil
        secondView = nil
        firstRect = .zero
        secondRect = .zero
        clearAnnotations()
        selectionHighlights.forEach { $0.removeFromSuperview() }
        selectionHighlights.removeAll()
        hintLabel.text = "TAP VIEW 1"
    }

    @objc private func handleDone() {
        onDone?()
    }
}
#endif
