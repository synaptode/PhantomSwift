#if DEBUG
import UIKit

// MARK: - PhantomTouchVisualizer

/// Draws animated touch ripples and velocity trails over all app interactions.
/// Uses UIApplication.sendEvent swizzle (one-time) to intercept every touch event
/// across all windows, then renders on a passthrough overlay window.
internal final class PhantomTouchVisualizer {

    internal static let shared = PhantomTouchVisualizer()
    private init() {}

    // MARK: - Config

    internal struct VisualizerConfig {
        /// Diameter of each touch circle in points.
        var circleSize: CGFloat = 60
        /// Whether to draw a velocity trail behind moving touches.
        var showTrails: Bool    = true
        /// Show a touch-count badge (e.g. "2 fingers") at the top of the overlay.
        var showCountBadge: Bool = true
        /// Color per finger — cycles when more touches than colors.
        var colors: [UIColor] = [
            UIColor.Phantom.neonAzure,
            UIColor.Phantom.vibrantOrange,
            UIColor.Phantom.vibrantGreen,
            UIColor.Phantom.vibrantPurple,
            UIColor.Phantom.vibrantRed
        ]
    }

    internal var config = VisualizerConfig()
    internal private(set) var isActive = false

    private var isSwizzled    = false
    private var overlayWindow: TVOverlayWindow?
    private var countBadge:   UILabel?
    private var rippleMap:    [ObjectIdentifier: TouchRippleView] = [:]
    private var colorIndex  = 0

    // MARK: - Start / Stop

    internal func start() {
        guard !isActive else { return }
        isActive = true

        // Swizzle once — we gate on isActive inside the swizzled method
        if !isSwizzled {
            isSwizzled = true
            PhantomSwizzler.swizzle(
                cls: UIApplication.self,
                originalSelector: #selector(UIApplication.sendEvent(_:)),
                swizzledSelector: #selector(UIApplication.phantom_tv_sendEvent(_:)))
        }

        let win = TVOverlayWindow(frame: UIScreen.main.bounds)
        win.windowLevel = UIWindow.Level.statusBar + 50
        win.isHidden    = false
        overlayWindow   = win

        if config.showCountBadge { installCountBadge(in: win) }
    }

    internal func stop() {
        guard isActive else { return }
        isActive = false
        rippleMap.values.forEach { $0.animateOut() }
        rippleMap.removeAll()
        colorIndex = 0
        countBadge?.removeFromSuperview()
        countBadge = nil
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }

    // MARK: - Event Processing (called from swizzled UIApplication.sendEvent)

    internal func process(_ event: UIEvent) {
        guard isActive, event.type == .touches, let touches = event.allTouches else { return }
        DispatchQueue.main.async { [weak self] in self?.handleTouches(touches) }
    }

    private func handleTouches(_ touches: Set<UITouch>) {
        guard let overlay = overlayWindow else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let pt = touch.location(in: overlay)
            switch touch.phase {
            case .began:
                let color  = nextColor()
                let ripple = TouchRippleView(
                    at: pt, color: color,
                    size: config.circleSize,
                    showTrail: config.showTrails)
                overlay.addSubview(ripple)
                ripple.animateIn()
                rippleMap[id] = ripple
                updateCountBadge()
            case .moved:
                rippleMap[id]?.move(to: pt)
            case .ended, .cancelled:
                rippleMap.removeValue(forKey: id)?.animateOut()
                updateCountBadge()
            default: break
            }
        }
    }

    private func nextColor() -> UIColor {
        guard !config.colors.isEmpty else { return UIColor.Phantom.neonAzure }
        let c = config.colors[colorIndex % config.colors.count]
        colorIndex = (colorIndex + 1) % config.colors.count
        return c
    }

    // MARK: - Count Badge

    private func installCountBadge(in window: UIWindow) {
        let lbl = UILabel()
        lbl.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .black)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        lbl.layer.cornerRadius = 12
        lbl.layer.masksToBounds = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.isHidden = true
        window.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            lbl.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            lbl.heightAnchor.constraint(equalToConstant: 24),
            lbl.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        countBadge = lbl
    }

    private func updateCountBadge() {
        let n = rippleMap.count
        countBadge?.isHidden = n < 2
        if n >= 2 {
            countBadge?.text = "  \(n) fingers  "
        }
    }
}

// MARK: - UIApplication Swizzle Target

extension UIApplication {
    /// Swizzled implementation of `sendEvent(_:)` — calls original then notifies touch visualizer.
    @objc func phantom_tv_sendEvent(_ event: UIEvent) {
        self.phantom_tv_sendEvent(event) // calls original (implementations are exchanged)
        PhantomTouchVisualizer.shared.process(event)
    }
}

// MARK: - TVOverlayWindow

/// Passthrough window: visible for drawing touch ripples, but never receives touch events.
internal final class TVOverlayWindow: UIWindow {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor          = .clear
        isUserInteractionEnabled = false
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                windowScene = scene
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Never intercept touches — let them pass through to the app.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

// MARK: - TouchRippleView

private final class TouchRippleView: UIView {

    private let dot       = UIView()
    private let ring      = UIView()
    private let outerRing = UIView()

    private let trailLayer = CAShapeLayer()
    private var trailPath  = UIBezierPath()
    private let showTrail: Bool
    private let color: UIColor

    init(at point: CGPoint, color: UIColor, size: CGFloat, showTrail: Bool) {
        self.color     = color
        self.showTrail = showTrail
        let half       = size / 2
        super.init(frame: CGRect(x: point.x - half, y: point.y - half, width: size, height: size))
        isUserInteractionEnabled = false
        buildViews(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildViews(size: CGFloat) {
        backgroundColor = .clear

        // Center dot
        let dotR: CGFloat = size * 0.1
        dot.frame              = CGRect(x: size / 2 - dotR, y: size / 2 - dotR, width: dotR * 2, height: dotR * 2)
        dot.backgroundColor    = color
        dot.layer.cornerRadius = dotR
        addSubview(dot)

        // Middle ring
        let ringR: CGFloat = size * 0.28
        ring.frame              = CGRect(x: size / 2 - ringR, y: size / 2 - ringR, width: ringR * 2, height: ringR * 2)
        ring.backgroundColor    = color.withAlphaComponent(0.12)
        ring.layer.cornerRadius = ringR
        ring.layer.borderWidth  = 1.5
        ring.layer.borderColor  = color.withAlphaComponent(0.7).cgColor
        addSubview(ring)

        // Outer pulsing ring
        outerRing.frame              = bounds
        outerRing.layer.cornerRadius = size / 2
        outerRing.layer.borderWidth  = 1
        outerRing.layer.borderColor  = color.withAlphaComponent(0.28).cgColor
        outerRing.backgroundColor    = .clear
        addSubview(outerRing)

        // Trail layer (added to superview in didMoveToSuperview)
        if showTrail {
            trailLayer.fillColor   = UIColor.clear.cgColor
            trailLayer.strokeColor = color.withAlphaComponent(0.38).cgColor
            trailLayer.lineWidth   = 2.5
            trailLayer.lineCap     = .round
            trailLayer.lineJoin    = .round
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard showTrail, let sv = superview else { return }
        trailPath = UIBezierPath()
        trailPath.move(to: center)
        sv.layer.insertSublayer(trailLayer, at: 0)
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if newSuperview == nil { trailLayer.removeFromSuperlayer() }
    }

    func animateIn() {
        alpha     = 0
        transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.alpha     = 1
            self.transform = .identity
        }
        let pulse           = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue     = 1.0
        pulse.toValue       = 1.12
        pulse.duration      = 0.6
        pulse.autoreverses  = true
        pulse.repeatCount   = .infinity
        outerRing.layer.add(pulse, forKey: "pulse")
    }

    func move(to pt: CGPoint) {
        center = pt
        if showTrail {
            trailPath.addLine(to: pt)
            trailLayer.path = trailPath.cgPath
        }
    }

    func animateOut() {
        outerRing.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn], animations: {
            self.alpha     = 0
            self.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        }) { [weak self] _ in
            self?.removeFromSuperview()
        }
    }
}

#endif
