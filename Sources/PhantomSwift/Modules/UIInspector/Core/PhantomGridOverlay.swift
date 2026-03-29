#if DEBUG
import UIKit

// MARK: - PhantomGridConfig

/// Configuration for the design grid overlay.
internal struct PhantomGridConfig {
    /// Number of columns (e.g. 4, 8, 12).
    var columns: Int             = 4
    /// Left + right margin from screen edge in points.
    var margin: CGFloat          = 20
    /// Space between columns in points.
    var gutter: CGFloat          = 16
    /// Show horizontal baseline grid lines.
    var showBaseline: Bool       = false
    /// Spacing between baseline lines in points.
    var baselineSpacing: CGFloat = 8
    /// Show horizontal and vertical center guide lines.
    var showCenterGuides: Bool   = false
    /// Color of column bands.
    var columnColor: UIColor     = UIColor.Phantom.vibrantRed.withAlphaComponent(0.20)
    /// Color of baseline grid lines.
    var baselineColor: UIColor   = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.20)
    /// Color of center guide lines.
    var centerColor: UIColor     = UIColor.Phantom.neonAzure.withAlphaComponent(0.55)
    /// Overall opacity of the overlay window (0–1).
    var opacity: Float           = 0.75
}

// MARK: - PhantomGridOverlay

/// Singleton that renders a configurable design grid on a transparent passthrough overlay window.
/// Updating `config` refreshes the grid in real time without hiding/showing the window.
internal final class PhantomGridOverlay {

    internal static let shared = PhantomGridOverlay()
    private init() {}

    private var overlayWindow: GridOverlayWindow?
    private var drawView:      GridDrawView?
    internal private(set) var isVisible = false

    internal var config = PhantomGridConfig() {
        didSet {
            drawView?.config = config
            overlayWindow?.alpha = CGFloat(config.opacity)
        }
    }

    // MARK: - Show / Hide / Toggle

    internal func show() {
        guard !isVisible else { return }
        isVisible = true

        let win         = GridOverlayWindow(frame: UIScreen.main.bounds)
        win.windowLevel = UIWindow.Level.statusBar + 40
        win.alpha       = CGFloat(config.opacity)
        win.isHidden    = false
        overlayWindow   = win

        let gv = GridDrawView(frame: win.bounds, config: config)
        gv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        win.addSubview(gv)
        drawView = gv
    }

    internal func hide() {
        guard isVisible else { return }
        isVisible = false
        overlayWindow?.isHidden = true
        overlayWindow = nil
        drawView      = nil
    }

    internal func toggle() {
        isVisible ? hide() : show()
    }

    /// Apply a mutation to the config (e.g. from a settings panel) and update live.
    internal func update(_ mutation: (inout PhantomGridConfig) -> Void) {
        mutation(&config)
    }
}

// MARK: - GridOverlayWindow

private final class GridOverlayWindow: UIWindow {

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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

// MARK: - GridDrawView

/// Draws column bands, optional baseline lines, and optional center guide lines using Core Graphics.
internal final class GridDrawView: UIView {

    var config: PhantomGridConfig {
        didSet { setNeedsDisplay() }
    }

    init(frame: CGRect, config: PhantomGridConfig) {
        self.config = config
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque        = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let w      = rect.width
        let h      = rect.height
        let cols   = max(1, config.columns)
        let margin = config.margin
        let gutter = config.gutter

        // --- Column bands ---
        let totalGutterWidth = gutter * CGFloat(cols - 1)
        let colWidth         = (w - margin * 2 - totalGutterWidth) / CGFloat(cols)

        if colWidth > 0 {
            ctx.setFillColor(config.columnColor.cgColor)
            for i in 0..<cols {
                let x = margin + CGFloat(i) * (colWidth + gutter)
                ctx.fill(CGRect(x: x, y: 0, width: colWidth, height: h))
            }

            // Gutter edge tick marks (top + bottom, 8pt tall)
            let tickColor = config.columnColor.withAlphaComponent(0.6)
            ctx.setFillColor(tickColor.cgColor)
            for i in 0...cols {
                // Left edge of column i (= right edge of gutter i-1)
                let x: CGFloat
                if i == 0 {
                    x = margin
                } else if i == cols {
                    x = margin + CGFloat(cols) * colWidth + CGFloat(cols - 1) * gutter
                } else {
                    x = margin + CGFloat(i) * (colWidth + gutter)
                }
                // Tiny 1pt vertical rule at each column boundary
                ctx.fill(CGRect(x: x - 0.5, y: 0, width: 1, height: h))
            }
        }

        // --- Baseline grid ---
        if config.showBaseline, config.baselineSpacing > 2 {
            ctx.setFillColor(config.baselineColor.cgColor)
            var y: CGFloat = config.baselineSpacing
            while y < h {
                ctx.fill(CGRect(x: 0, y: y, width: w, height: 0.5))
                y += config.baselineSpacing
            }
        }

        // --- Center guides ---
        if config.showCenterGuides {
            let dash: [CGFloat] = [6, 5]
            ctx.setLineDash(phase: 0, lengths: dash)
            ctx.setLineWidth(1)
            ctx.setStrokeColor(config.centerColor.cgColor)

            ctx.move(to: CGPoint(x: 0,     y: h / 2))
            ctx.addLine(to: CGPoint(x: w,  y: h / 2))
            ctx.move(to: CGPoint(x: w / 2, y: 0))
            ctx.addLine(to: CGPoint(x: w / 2, y: h))
            ctx.strokePath()
        }
    }
}

#endif
