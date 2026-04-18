#if DEBUG
import UIKit

// MARK: - ColorPickerVC

/// Full-screen pixel-level color sampler.
/// Captures the app window state as a screenshot, overlays a drag-to-sample crosshair,
/// shows a magnified loupe (4× zoom), and displays hex / RGB / HSL values in real time.
internal final class ColorPickerVC: UIViewController {

    // MARK: - Public

    var onColorPicked: ((UIColor, String) -> Void)?

    // MARK: - Private

    private let screenshot:    UIImage
    private let imageView      = UIImageView()
    private let crosshair      = CrosshairView()
    private let loupeContainer = UIView()
    private let loupeImageView = UIImageView()
    private let loupeBorder    = UIView()
    private let loupeReticle   = UIView()
    private let infoPanel      = UIVisualEffectView(effect: PhantomTheme.shared.glassEffect)
    private let swatchView     = UIView()
    private let hexLabel       = UILabel()
    private let rgbLabel       = UILabel()
    private let hslLabel       = UILabel()
    private let copyHexBtn     = UIButton(type: .system)
    private let doneBtn        = UIButton(type: .system)

    private var currentColor: UIColor = .black
    private var currentHex: String    = "#000000"

    // Loupe is visible when dragging, hidden initially
    private var isPicking = false

    // MARK: - Init

    internal init(screenshot: UIImage, onColorPicked: ((UIColor, String) -> Void)? = nil) {
        self.screenshot      = screenshot
        self.onColorPicked   = onColorPicked
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
        setupLoupe()
        setupInfoPanel()
        setupGestures()
        setupDimOverlay()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupImageView() {
        imageView.image = screenshot
        imageView.contentMode = .scaleAspectFill
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)
    }

    private func setupDimOverlay() {
        let dim = UIView(frame: view.bounds)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(dim)

        // Instruction label
        let hint = UILabel()
        hint.text = "Drag to sample color"
        hint.font = .systemFont(ofSize: 12, weight: .black)
        hint.textColor = UIColor.white.withAlphaComponent(0.7)
        hint.textAlignment = .center
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        hint.layer.cornerRadius = 10
        hint.layer.masksToBounds = true
        hint.translatesAutoresizingMaskIntoConstraints = false
        dim.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: dim.safeAreaLayoutGuide.topAnchor, constant: 12),
            hint.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            hint.heightAnchor.constraint(equalToConstant: 32),
            hint.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }

    private func setupLoupe() {
        // Container — circular clip
        loupeContainer.frame        = CGRect(x: 0, y: 0, width: 140, height: 140)
        loupeContainer.layer.cornerRadius = 70
        loupeContainer.layer.masksToBounds = true
        loupeContainer.alpha        = 0
        loupeContainer.isHidden     = true
        view.addSubview(loupeContainer)

        // Magnified image inside loupe
        loupeImageView.frame        = loupeContainer.bounds
        loupeImageView.contentMode  = .scaleAspectFill
        loupeImageView.layer.magnificationFilter = .nearest // pixel-crisp
        loupeContainer.addSubview(loupeImageView)

        // Cross-reticle overlay (center pixel indicator)
        loupeReticle.frame           = CGRect(x: 0, y: 0, width: 140, height: 140)
        loupeReticle.backgroundColor = .clear
        loupeContainer.insertSubview(loupeReticle, aboveSubview: loupeImageView)
        loupeReticle.isUserInteractionEnabled = false

        // Loupe outer border
        loupeBorder.frame           = CGRect(x: -3, y: -3, width: 146, height: 146)
        loupeBorder.layer.cornerRadius = 73
        loupeBorder.layer.borderWidth  = 3
        loupeBorder.layer.borderColor  = UIColor.white.cgColor
        loupeBorder.layer.shadowColor  = UIColor.black.cgColor
        loupeBorder.layer.shadowOpacity = 0.6
        loupeBorder.layer.shadowRadius  = 8
        loupeBorder.layer.shadowOffset  = .zero
        loupeBorder.backgroundColor     = .clear
        loupeBorder.isUserInteractionEnabled = false
        view.insertSubview(loupeBorder, aboveSubview: loupeContainer)

        // Crosshair center dot
        crosshair.frame = CGRect(x: 0, y: 0, width: 140, height: 140)
        crosshair.alpha = 0.9
        crosshair.backgroundColor = .clear
        crosshair.isUserInteractionEnabled = false
        loupeContainer.addSubview(crosshair)
    }

    private func setupInfoPanel() {
        infoPanel.layer.cornerRadius = 20
        infoPanel.layer.masksToBounds = true
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoPanel)

        // Color swatch
        swatchView.layer.cornerRadius = 12
        swatchView.layer.borderWidth  = 1.5
        swatchView.layer.borderColor  = UIColor.white.withAlphaComponent(0.2).cgColor
        swatchView.backgroundColor    = .black
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.contentView.addSubview(swatchView)

        // Hex
        hexLabel.text      = "#000000"
        hexLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .black)
        hexLabel.textColor = .white
        hexLabel.textAlignment = .left
        hexLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.contentView.addSubview(hexLabel)

        // RGB
        rgbLabel.text      = "R: 0   G: 0   B: 0"
        rgbLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        rgbLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        rgbLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.contentView.addSubview(rgbLabel)

        // HSL
        hslLabel.text      = "H: 0°   S: 0%   L: 0%"
        hslLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        hslLabel.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.7)
        hslLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.contentView.addSubview(hslLabel)

        // Copy Hex button
        copyHexBtn.setTitle("Copy Hex", for: .normal)
        copyHexBtn.titleLabel?.font    = .systemFont(ofSize: 13, weight: .bold)
        copyHexBtn.setTitleColor(UIColor.Phantom.vibrantGreen, for: .normal)
        copyHexBtn.backgroundColor     = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.1)
        copyHexBtn.layer.cornerRadius   = 10
        copyHexBtn.layer.borderWidth    = 1
        copyHexBtn.layer.borderColor    = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.3).cgColor
        copyHexBtn.translatesAutoresizingMaskIntoConstraints = false
        copyHexBtn.addTarget(self, action: #selector(copyHex), for: .touchUpInside)
        infoPanel.contentView.addSubview(copyHexBtn)

        // Done button
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.titleLabel?.font    = .systemFont(ofSize: 13, weight: .bold)
        doneBtn.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        doneBtn.backgroundColor      = UIColor.white.withAlphaComponent(0.08)
        doneBtn.layer.cornerRadius   = 10
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.addTarget(self, action: #selector(handleDone), for: .touchUpInside)
        infoPanel.contentView.addSubview(doneBtn)

        let btnStack = UIStackView(arrangedSubviews: [copyHexBtn, doneBtn])
        btnStack.axis         = .horizontal
        btnStack.spacing      = 8
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.contentView.addSubview(btnStack)

        NSLayoutConstraint.activate([
            infoPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            infoPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            swatchView.leadingAnchor.constraint(equalTo: infoPanel.contentView.leadingAnchor, constant: 16),
            swatchView.topAnchor.constraint(equalTo: infoPanel.contentView.topAnchor, constant: 16),
            swatchView.widthAnchor.constraint(equalToConstant: 52),
            swatchView.heightAnchor.constraint(equalToConstant: 52),

            hexLabel.leadingAnchor.constraint(equalTo: swatchView.trailingAnchor, constant: 14),
            hexLabel.topAnchor.constraint(equalTo: swatchView.topAnchor),
            hexLabel.trailingAnchor.constraint(equalTo: infoPanel.contentView.trailingAnchor, constant: -16),

            rgbLabel.leadingAnchor.constraint(equalTo: hexLabel.leadingAnchor),
            rgbLabel.topAnchor.constraint(equalTo: hexLabel.bottomAnchor, constant: 4),

            hslLabel.leadingAnchor.constraint(equalTo: hexLabel.leadingAnchor),
            hslLabel.topAnchor.constraint(equalTo: rgbLabel.bottomAnchor, constant: 2),

            btnStack.topAnchor.constraint(equalTo: swatchView.bottomAnchor, constant: 12),
            btnStack.leadingAnchor.constraint(equalTo: infoPanel.contentView.leadingAnchor, constant: 16),
            btnStack.trailingAnchor.constraint(equalTo: infoPanel.contentView.trailingAnchor, constant: -16),
            btnStack.heightAnchor.constraint(equalToConstant: 40),
            btnStack.bottomAnchor.constraint(equalTo: infoPanel.contentView.bottomAnchor, constant: -16)
        ])
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let pt = gr.location(in: view)

        switch gr.state {
        case .began:
            isPicking = true
            loupeContainer.isHidden = false
            UIView.animate(withDuration: 0.15) { self.loupeContainer.alpha = 1 }
        case .changed, .ended, .cancelled:
            break
        default:
            break
        }

        if gr.state == .ended || gr.state == .cancelled {
            UIView.animate(withDuration: 0.2, delay: 0.4, options: [], animations: {
                self.loupeContainer.alpha = 0
            }) { _ in
                self.loupeContainer.isHidden = true
            }
        }

        updateLoupe(at: pt)
        updateInfoPanel(for: pt)
    }

    // MARK: - Loupe & Sampling

    private func updateLoupe(at touchPt: CGPoint) {
        // Position: offset above and to the right of the finger
        let offset: CGFloat = 90
        var loupePt = CGPoint(x: touchPt.x + offset, y: touchPt.y - offset - 70)
        loupePt.x = max(10, min(view.bounds.width  - 150, loupePt.x))
        loupePt.y = max(10, min(view.bounds.height - 200, loupePt.y))

        loupeContainer.center = CGPoint(x: loupePt.x + 70, y: loupePt.y + 70)
        loupeBorder.center    = loupeContainer.center

        // Crop region: 30×30 points centered on touch → displayed in 140pt = ~4.7× zoom
        let cropPtRadius: CGFloat = 15
        let cropRect = CGRect(
            x: touchPt.x - cropPtRadius,
            y: touchPt.y - cropPtRadius,
            width: cropPtRadius * 2,
            height: cropPtRadius * 2)

        loupeImageView.image = croppedImage(from: screenshot, rect: cropRect,  viewSize: view.bounds.size)
    }

    /// Crops `rect` (in view-point coordinates) from the screenshot and returns a scaled-up UIImage
    private func croppedImage(from image: UIImage, rect: CGRect, viewSize: CGSize) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = image.scale

        // Convert from view points to image pixels
        let scaleX = image.size.width  / viewSize.width
        let scaleY = image.size.height / viewSize.height

        let pixelRect = CGRect(
            x: rect.origin.x    * scaleX * scale,
            y: rect.origin.y    * scaleY * scale,
            width:  rect.width  * scaleX * scale,
            height: rect.height * scaleY * scale)

        guard let cgImg = image.cgImage,
              let cropped = cgImg.cropping(to: pixelRect) else { return nil }

        return UIImage(cgImage: cropped, scale: 1, orientation: image.imageOrientation)
    }

    private func sampleColor(at touchPt: CGPoint, viewSize: CGSize) -> UIColor {
        guard screenshot.size.width > 0, screenshot.size.height > 0 else { return .black }

        let scaleX = screenshot.size.width  / viewSize.width
        let scaleY = screenshot.size.height / viewSize.height
        let sc     = screenshot.scale

        let px = Int(touchPt.x * scaleX * sc)
        let py = Int(touchPt.y * scaleY * sc)

        let colorSpace  = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo  = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var pixel       = [UInt8](repeating: 0, count: 4)

        guard let cgImg = screenshot.cgImage,
              let ctx = CGContext(data: &pixel, width: 1, height: 1,
                                  bitsPerComponent: 8, bytesPerRow: 4,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else {
            return .black
        }
        ctx.translateBy(x: CGFloat(-px), y: CGFloat(-py))
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: cgImg.width, height: cgImg.height))

        let alpha = CGFloat(pixel[3]) / 255.0
        guard alpha > 0 else { return .clear }
        // Undo premultiplied alpha
        return UIColor(
            red:   CGFloat(pixel[0]) / 255.0 / alpha,
            green: CGFloat(pixel[1]) / 255.0 / alpha,
            blue:  CGFloat(pixel[2]) / 255.0 / alpha,
            alpha: alpha)
    }

    private func updateInfoPanel(for pt: CGPoint) {
        let color  = sampleColor(at: pt, viewSize: view.bounds.size)
        currentColor = color

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        currentHex = hex

        swatchView.backgroundColor = color
        hexLabel.text  = hex

        rgbLabel.text  = String(format: "R: %d   G: %d   B: %d",
                                 Int(r * 255), Int(g * 255), Int(b * 255))

        let (h, s, l)  = rgbToHSL(r: r, g: g, b: b)
        hslLabel.text  = String(format: "H: %.0f°   S: %.0f%%   L: %.0f%%",
                                 h * 360, s * 100, l * 100)

        // Loupeborder color mirrors sampled color for quick context
        loupeBorder.layer.borderColor = color.cgColor
    }

    // MARK: - Color Math

    private func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        let max_ = max(r, g, b)
        let min_ = min(r, g, b)
        let l    = (max_ + min_) / 2
        guard max_ != min_ else { return (0, 0, l) }

        let d = max_ - min_
        let s = l > 0.5 ? d / (2 - max_ - min_) : d / (max_ + min_)

        var h: CGFloat
        switch max_ {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    // MARK: - Actions

    @objc private func copyHex() {
        UIPasteboard.general.string = currentHex
        onColorPicked?(currentColor, currentHex)

        let originalTitle = copyHexBtn.title(for: .normal)
        copyHexBtn.setTitle("✓ Copied!", for: .normal)
        copyHexBtn.setTitleColor(UIColor.Phantom.vibrantGreen, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyHexBtn.setTitle(originalTitle, for: .normal)
        }
    }

    @objc private func handleDone() {
        dismiss(animated: true)
    }
}

// MARK: - CrosshairView

private final class CrosshairView: UIView {

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cx = rect.midX
        let cy = rect.midY
        let r: CGFloat  = 6  // center dot radius
        let gap: CGFloat = 4  // gap between dot and lines

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [])

        // Horizontal lines
        ctx.move(to: CGPoint(x: 0, y: cy))
        ctx.addLine(to: CGPoint(x: cx - r - gap, y: cy))
        ctx.move(to: CGPoint(x: cx + r + gap, y: cy))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: cy))

        // Vertical lines
        ctx.move(to: CGPoint(x: cx, y: 0))
        ctx.addLine(to: CGPoint(x: cx, y: cy - r - gap))
        ctx.move(to: CGPoint(x: cx, y: cy + r + gap))
        ctx.addLine(to: CGPoint(x: cx, y: rect.maxY))
        ctx.strokePath()

        // Center circle
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.strokePath()
    }
}

// MARK: - UIView extension for ColorPickerVC capture

extension UIView {
    /// Convenience: capture a UIImage of the full app window before presenting ColorPickerVC.
    static func captureAppWindow() -> UIImage? {
        guard let window = PhantomPresentationResolver.activeHostWindow() else {
            return nil
        }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

#endif
