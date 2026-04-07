#if DEBUG
import UIKit
import QuartzCore

// MARK: - Snapshot metadata

private struct SnapshotMeta {
    let snapshotLayer: CALayer
    let sourceView: UIView
    let depth: Int
    let originalFrame: CGRect
    let className: String
    let alpha: CGFloat
    let isHidden: Bool
    let accessibilityID: String?
    let constraintCount: Int
    let subviewCount: Int
    let address: String
    let parentClassName: String?
    let backgroundColor: UIColor?
}

// MARK: - ViewHierarchy3DVC

/// FLEX / DebugSwift-style 3D exploded view of a live UIView hierarchy.
///
/// Each view is rasterized into a CALayer texture and stacked in z-space
/// at its real screen position. Supports: orbit, zoom, pan, depth range
/// filter, wireframe mode, class name labels, focus-on-layer, animated
/// layer entry, mini-map overlay, and a rich inspector bottom sheet.
internal final class ViewHierarchy3DVC: UIViewController {

    // MARK: - Data

    private let sourceRootView: UIView
    private var snapshots: [SnapshotMeta] = []
    private var filteredIndices: [Int] = []       // indices into `snapshots` after depth filter
    private var maxDepth: Int = 0
    private var selectedIndex: Int? {             // index into `snapshots`
        didSet { applySelection() }
    }

    // MARK: - 3D Scene

    private let sceneContainer = UIView()
    private let transformLayer = CATransformLayer()

    private var angleX: CGFloat = -.pi / 9
    private var angleY: CGFloat = .pi / 12
    private var translateX: CGFloat = 0
    private var translateY: CGFloat = 0
    private var zoom: CGFloat = 1.0
    private var spacing: CGFloat = 24

    // MARK: - Modes

    private var isWireframe = false
    private var showHidden = false
    private var showLabels = true
    private var depthMin: Int = 0
    private var depthMax: Int = .max
    private var searchQuery: String = ""
    private var isCleanedUp = false

    // MARK: - Toolbar

    private let toolbar = UIView()
    private let spacingSlider = UISlider()
    private let depthRangeSlider = UISlider()     // max-depth filter
    private let rotateXSlider = UISlider()
    private let rotateYSlider = UISlider()
    private let spacingValueLabel = UILabel()
    private let depthValueLabel = UILabel()
    private let rotateXValueLabel = UILabel()
    private let rotateYValueLabel = UILabel()
    private let countBadge = UILabel()
    private let zoomBadge = UILabel()

    private let wireframeBtn = UIButton(type: .system)
    private let hiddenBtn = UIButton(type: .system)
    private let labelsBtn = UIButton(type: .system)
    private let focusBtn = UIButton(type: .system)
    private let fitAllBtn = UIButton(type: .system)
    private let resetBtn = UIButton(type: .system)

    // MARK: - Mini-map

    private let miniMapContainer = UIView()
    private let miniMapImageView = UIImageView()

    // MARK: - Inspector

    private let inspectorPanel = UIView()
    private let inspectorScroll = UIScrollView()
    private let inspectorStack = UIStackView()
    private let inspectorClose = UIButton(type: .system)
    private let inspectorBreadcrumb = UILabel()
    private var inspectorBottom: NSLayoutConstraint?
    private let inspectorHeight: CGFloat = 340

    // MARK: - Init

    internal init(rootView: UIView?) {
        self.sourceRootView = rootView ?? UIView()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        captureHierarchy()
        rebuildScene(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        transformLayer.position = CGPoint(x: sceneContainer.bounds.midX,
                                          y: sceneContainer.bounds.midY)
        updateMiniMap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }

    deinit {
        cleanup()
    }

    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true

        // Remove all gestures from scene container
        if let gestures = sceneContainer.gestureRecognizers {
            for gesture in gestures {
                sceneContainer.removeGestureRecognizer(gesture)
            }
        }

        // Remove all gestures from inspector panel
        if let gestures = inspectorPanel.gestureRecognizers {
            for gesture in gestures {
                inspectorPanel.removeGestureRecognizer(gesture)
            }
        }

        // Clear all CALayers to prevent memory leak
        transformLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        transformLayer.removeFromSuperlayer()

        // Release snapshot references
        snapshots.removeAll(keepingCapacity: false)
        filteredIndices.removeAll(keepingCapacity: false)

        // Clear view references
        selectedIndex = nil
    }

    // MARK: - Build UI
    // ──────────────────────────────────────────────────────────────────────

    private func buildUI() {
        title = "3D Hierarchy"
        view.backgroundColor = UIColor.Phantom.backgroundDark

        // nav bar
        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()
            a.backgroundColor = UIColor.Phantom.surfaceDark
            a.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationItem.standardAppearance = a
            navigationItem.scrollEdgeAppearance = a
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .done, target: self, action: #selector(dismissVC))

        // scene
        sceneContainer.backgroundColor = .clear
        sceneContainer.clipsToBounds = false
        sceneContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneContainer)

        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 900.0
        sceneContainer.layer.sublayerTransform = perspective
        sceneContainer.layer.addSublayer(transformLayer)

        // toolbar
        buildToolbar()

        // mini-map
        buildMiniMap()

        // inspector
        buildInspector()

        // layout
        NSLayoutConstraint.activate([
            sceneContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sceneContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneContainer.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])

        // gestures
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        sceneContainer.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        sceneContainer.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(resetCamera))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        sceneContainer.addGestureRecognizer(tap)
        sceneContainer.addGestureRecognizer(doubleTap)
    }

    // MARK: Toolbar

    private func buildToolbar() {
        setupToolbarBase()
        let sep = addSeparator()
        let sliderRows = buildSliderRows()
        let btnScroll = buildActionButtons()
        buildStatusBadges()
        setupToolbarConstraints(sep: sep, spacingRow: sliderRows.0, depthRow: sliderRows.1, rotateXRow: sliderRows.2, rotateYRow: sliderRows.3, btnScroll: btnScroll)
    }

    private func setupToolbarBase() {
        toolbar.backgroundColor = UIColor.Phantom.surfaceDark
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
    }

    private func addSeparator() -> UIView {
        let sep = hairline()
        toolbar.addSubview(sep)
        return sep
    }

    private func buildSliderRows() -> (UIView, UIView, UIView, UIView) {
        // row 1: spacing slider
        let spacingRow = sliderRow(label: "Spacing", value: spacing,
                                   min: 4, max: 80, color: UIColor.Phantom.neonAzure,
                                   valueLbl: spacingValueLabel, slider: spacingSlider,
                                   action: #selector(spacingDidChange))
        toolbar.addSubview(spacingRow)

        // row 2: depth range slider
        let depthRow = sliderRow(label: "Depth", value: 0,
                                  min: 0, max: 20, color: UIColor.Phantom.vibrantGreen,
                                  valueLbl: depthValueLabel, slider: depthRangeSlider,
                                  action: #selector(depthDidChange))
        toolbar.addSubview(depthRow)

        // row 3: rotate X slider
        let rotateXRow = sliderRow(label: "Rotate X", value: CGFloat(angleX),
                                   min: Float(-Float.pi / 2), max: Float(Float.pi / 2),
                                   color: UIColor.Phantom.vibrantOrange,
                                   valueLbl: rotateXValueLabel, slider: rotateXSlider,
                                   action: #selector(rotateXDidChange))
        toolbar.addSubview(rotateXRow)

        // row 4: rotate Y slider
        let rotateYRow = sliderRow(label: "Rotate Y", value: CGFloat(angleY),
                                   min: Float(-Float.pi), max: Float(Float.pi),
                                   color: UIColor.Phantom.vibrantRed,
                                   valueLbl: rotateYValueLabel, slider: rotateYSlider,
                                   action: #selector(rotateYDidChange))
        toolbar.addSubview(rotateYRow)

        // Set initial rotation label values
        rotateXValueLabel.text = "\(Int(angleX * 180 / CGFloat.pi))°"
        rotateYValueLabel.text = "\(Int(angleY * 180 / CGFloat.pi))°"

        return (spacingRow, depthRow, rotateXRow, rotateYRow)
    }

    private func buildActionButtons() -> UIView {
        // row 5: buttons
        let btnScroll = UIScrollView()
        btnScroll.showsHorizontalScrollIndicator = false
        btnScroll.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(btnScroll)

        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 8
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        btnScroll.addSubview(btnStack)

        configBtn(wireframeBtn, title: "Wireframe", color: UIColor.Phantom.vibrantPurple,
                  action: #selector(toggleWireframe))
        configBtn(hiddenBtn, title: "Hidden", color: UIColor.Phantom.vibrantOrange,
                  action: #selector(toggleHidden))
        configBtn(labelsBtn, title: "Labels", color: UIColor.Phantom.vibrantGreen,
                  action: #selector(toggleLabels))
        configBtn(focusBtn, title: "Focus", color: UIColor.Phantom.neonAzure,
                  action: #selector(focusSelected))
        configBtn(fitAllBtn, title: "Fit All", color: UIColor.Phantom.vibrantRed,
                  action: #selector(fitAllLayers))
        configBtn(resetBtn, title: "Reset", color: UIColor.Phantom.vibrantTeal,
                  action: #selector(resetCamera))

        // labels on by default
        styleBtn(labelsBtn, color: UIColor.Phantom.vibrantGreen, active: true)

        for b in [wireframeBtn, hiddenBtn, labelsBtn, focusBtn, fitAllBtn, resetBtn] {
            btnStack.addArrangedSubview(b)
        }

        NSLayoutConstraint.activate([
            btnStack.topAnchor.constraint(equalTo: btnScroll.topAnchor),
            btnStack.leadingAnchor.constraint(equalTo: btnScroll.leadingAnchor),
            btnStack.trailingAnchor.constraint(equalTo: btnScroll.trailingAnchor),
            btnStack.bottomAnchor.constraint(equalTo: btnScroll.bottomAnchor),
            btnStack.heightAnchor.constraint(equalTo: btnScroll.heightAnchor)
        ])

        return btnScroll
    }

    private func buildStatusBadges() {
        // row 4: badges
        if #available(iOS 13.0, *) {
            countBadge.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        } else {
            countBadge.font = .systemFont(ofSize: 10, weight: .bold)
        }
        countBadge.textColor = UIColor.Phantom.vibrantGreen
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(countBadge)

        if #available(iOS 13.0, *) {
            zoomBadge.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        } else {
            zoomBadge.font = .systemFont(ofSize: 10, weight: .bold)
        }
        zoomBadge.textColor = UIColor.Phantom.vibrantPurple
        zoomBadge.textAlignment = .right
        zoomBadge.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(zoomBadge)
    }

    private func setupToolbarConstraints(sep: UIView, spacingRow: UIView, depthRow: UIView, rotateXRow: UIView, rotateYRow: UIView, btnScroll: UIView) {
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            sep.topAnchor.constraint(equalTo: toolbar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            spacingRow.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 8),
            spacingRow.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            spacingRow.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            spacingRow.heightAnchor.constraint(equalToConstant: 24),

            depthRow.topAnchor.constraint(equalTo: spacingRow.bottomAnchor, constant: 6),
            depthRow.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            depthRow.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            depthRow.heightAnchor.constraint(equalToConstant: 24),

            rotateXRow.topAnchor.constraint(equalTo: depthRow.bottomAnchor, constant: 6),
            rotateXRow.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            rotateXRow.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            rotateXRow.heightAnchor.constraint(equalToConstant: 24),

            rotateYRow.topAnchor.constraint(equalTo: rotateXRow.bottomAnchor, constant: 6),
            rotateYRow.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            rotateYRow.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            rotateYRow.heightAnchor.constraint(equalToConstant: 24),

            btnScroll.topAnchor.constraint(equalTo: rotateYRow.bottomAnchor, constant: 8),
            btnScroll.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            btnScroll.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            btnScroll.heightAnchor.constraint(equalToConstant: 32),

            countBadge.topAnchor.constraint(equalTo: btnScroll.bottomAnchor, constant: 4),
            countBadge.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            countBadge.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -4),

            zoomBadge.centerYAnchor.constraint(equalTo: countBadge.centerYAnchor),
            zoomBadge.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
        ])
    }

    // MARK: Mini-map (top-right corner)

    private func buildMiniMap() {
        miniMapContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        miniMapContainer.layer.cornerRadius = 8
        miniMapContainer.layer.borderWidth = 1
        miniMapContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        miniMapContainer.clipsToBounds = true
        miniMapContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(miniMapContainer)

        miniMapImageView.contentMode = .scaleAspectFit
        miniMapImageView.translatesAutoresizingMaskIntoConstraints = false
        miniMapContainer.addSubview(miniMapImageView)

        NSLayoutConstraint.activate([
            miniMapContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            miniMapContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            miniMapContainer.widthAnchor.constraint(equalToConstant: 80),
            miniMapContainer.heightAnchor.constraint(equalToConstant: 120),

            miniMapImageView.topAnchor.constraint(equalTo: miniMapContainer.topAnchor, constant: 4),
            miniMapImageView.leadingAnchor.constraint(equalTo: miniMapContainer.leadingAnchor, constant: 4),
            miniMapImageView.trailingAnchor.constraint(equalTo: miniMapContainer.trailingAnchor, constant: -4),
            miniMapImageView.bottomAnchor.constraint(equalTo: miniMapContainer.bottomAnchor, constant: -4),
        ])
    }

    private func updateMiniMap() {
        // Render a tiny 2D overview of the root view as reference
        guard sourceRootView.bounds.width > 0 && sourceRootView.bounds.height > 0 else { return }
        let size = CGSize(width: 72, height: 108)
        let renderer = UIGraphicsImageRenderer(size: size)
        miniMapImageView.image = renderer.image { ctx in
            let scale = min(size.width / sourceRootView.bounds.width,
                            size.height / sourceRootView.bounds.height)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            sourceRootView.layer.render(in: ctx.cgContext)
        }
    }

    // MARK: Inspector bottom sheet

    private func buildInspector() {
        inspectorPanel.backgroundColor = UIColor.Phantom.surfaceDark
        inspectorPanel.layer.cornerRadius = 20
        inspectorPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        inspectorPanel.layer.borderWidth = 1
        inspectorPanel.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        inspectorPanel.clipsToBounds = true
        inspectorPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inspectorPanel)

        // drag handle
        let handle = UIView()
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        inspectorPanel.addSubview(handle)

        inspectorClose.setTitle("✕", for: .normal)
        inspectorClose.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        inspectorClose.tintColor = UIColor.white.withAlphaComponent(0.5)
        inspectorClose.addTarget(self, action: #selector(closeInspector), for: .touchUpInside)
        inspectorClose.translatesAutoresizingMaskIntoConstraints = false
        inspectorPanel.addSubview(inspectorClose)

        inspectorScroll.showsVerticalScrollIndicator = true
        inspectorScroll.translatesAutoresizingMaskIntoConstraints = false
        inspectorPanel.addSubview(inspectorScroll)

        inspectorStack.axis = .vertical
        inspectorStack.spacing = 0
        inspectorStack.translatesAutoresizingMaskIntoConstraints = false
        inspectorScroll.addSubview(inspectorStack)

        let bottom = inspectorPanel.bottomAnchor.constraint(
            equalTo: view.bottomAnchor, constant: inspectorHeight)
        inspectorBottom = bottom

        NSLayoutConstraint.activate([
            inspectorPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inspectorPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inspectorPanel.heightAnchor.constraint(equalToConstant: inspectorHeight),
            bottom,

            handle.topAnchor.constraint(equalTo: inspectorPanel.topAnchor, constant: 8),
            handle.centerXAnchor.constraint(equalTo: inspectorPanel.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5),

            inspectorClose.topAnchor.constraint(equalTo: inspectorPanel.topAnchor, constant: 10),
            inspectorClose.trailingAnchor.constraint(equalTo: inspectorPanel.trailingAnchor, constant: -16),
            inspectorClose.widthAnchor.constraint(equalToConstant: 30),
            inspectorClose.heightAnchor.constraint(equalToConstant: 30),

            inspectorScroll.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 8),
            inspectorScroll.leadingAnchor.constraint(equalTo: inspectorPanel.leadingAnchor),
            inspectorScroll.trailingAnchor.constraint(equalTo: inspectorPanel.trailingAnchor),
            inspectorScroll.bottomAnchor.constraint(equalTo: inspectorPanel.bottomAnchor),

            inspectorStack.topAnchor.constraint(equalTo: inspectorScroll.topAnchor),
            inspectorStack.leadingAnchor.constraint(equalTo: inspectorScroll.leadingAnchor, constant: 20),
            inspectorStack.trailingAnchor.constraint(equalTo: inspectorScroll.trailingAnchor, constant: -20),
            inspectorStack.bottomAnchor.constraint(equalTo: inspectorScroll.bottomAnchor, constant: -12),
            inspectorStack.widthAnchor.constraint(equalTo: inspectorScroll.widthAnchor, constant: -40),
        ])

        // Bring close button above scroll view so it's tappable
        inspectorPanel.bringSubviewToFront(inspectorClose)

        // Swipe-down to dismiss
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(closeInspector))
        swipeDown.direction = .down
        inspectorPanel.addGestureRecognizer(swipeDown)
    }

    private func showInspector(for meta: SnapshotMeta) {
        // rebuild content
        inspectorStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // breadcrumb path
        let breadcrumb = UILabel()
        breadcrumb.text = buildBreadcrumb(for: meta)
        breadcrumb.font = .systemFont(ofSize: 9, weight: .medium)
        breadcrumb.textColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.7)
        breadcrumb.numberOfLines = 0
        inspectorStack.addArrangedSubview(breadcrumb)
        inspectorStack.setCustomSpacing(8, after: breadcrumb)

        // title
        let title = UILabel()
        title.text = meta.className
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = .white
        inspectorStack.addArrangedSubview(title)
        inspectorStack.setCustomSpacing(4, after: title)

        // address
        let addr = UILabel()
        addr.text = meta.address
        if #available(iOS 13.0, *) {
            addr.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        } else {
            addr.font = .systemFont(ofSize: 10, weight: .regular)
        }
        addr.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.6)
        inspectorStack.addArrangedSubview(addr)
        inspectorStack.setCustomSpacing(12, after: addr)

        // info pills
        let pillStack = UIStackView()
        pillStack.axis = .horizontal
        pillStack.spacing = 6
        pillStack.distribution = .fill
        let f = meta.originalFrame
        pillStack.addArrangedSubview(makePill(
            String(format: "%.0f×%.0f", f.width, f.height),
            color: UIColor.Phantom.vibrantGreen))
        pillStack.addArrangedSubview(makePill(
            "d:\(meta.depth)",
            color: UIColor.Phantom.vibrantPurple))
        pillStack.addArrangedSubview(makePill(
            "\(meta.subviewCount) sub",
            color: UIColor.Phantom.vibrantOrange))
        if meta.isHidden {
            pillStack.addArrangedSubview(makePill("hidden", color: UIColor.Phantom.vibrantRed))
        }
        pillStack.addArrangedSubview(UIView()) // spacer
        inspectorStack.addArrangedSubview(pillStack)
        inspectorStack.setCustomSpacing(12, after: pillStack)

        // detail rows
        let rows: [(String, String)] = [
            ("Frame",         String(format: "(%.0f, %.0f, %.0f, %.0f)", f.origin.x, f.origin.y, f.width, f.height)),
            ("Alpha",         String(format: "%.2f", meta.alpha)),
            ("Hidden",        meta.isHidden ? "Yes" : "No"),
            ("Constraints",   "\(meta.constraintCount)"),
            ("Subviews",      "\(meta.subviewCount)"),
            ("Parent",        meta.parentClassName ?? "—"),
            ("Accessibility", meta.accessibilityID ?? "—"),
            ("Background",    meta.backgroundColor.map { describeColor($0) } ?? "nil"),
        ]
        for (label, value) in rows {
            inspectorStack.addArrangedSubview(makeRow(label: label, value: value))
        }

        // animate in
        inspectorBottom?.constant = 0
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0, options: .curveEaseOut, animations: { [weak self] in
            self?.view.layoutIfNeeded()
        })
    }

    private func buildBreadcrumb(for meta: SnapshotMeta) -> String {
        // Build hierarchy path from root to this view
        var path = [meta.className]
        
        // Walk back through parents by searching for views that contain this one
        // (simple heuristic: views at lower depths that contain similar subview count patterns)
        if let parent = meta.parentClassName {
            path.insert(parent, at: 0)
        }
        
        let breadcrumbStr = path.joined(separator: " › ")
        return "🔗 \(breadcrumbStr)"
    }

    @objc private func closeInspector() {
        selectedIndex = nil
        inspectorBottom?.constant = inspectorHeight
        UIView.animate(withDuration: 0.3) { [weak self] in self?.view.layoutIfNeeded() }
    }

    // MARK: - Capture Hierarchy
    // ──────────────────────────────────────────────────────────────────────

    private func captureHierarchy() {
        snapshots.removeAll()
        maxDepth = 0
        captureView(sourceRootView, depth: 0, parentClass: nil)
        depthRangeSlider.maximumValue = max(Float(maxDepth), 1)
        depthRangeSlider.value = Float(maxDepth)
        depthMax = maxDepth
        depthValueLabel.text = "≤ \(maxDepth)"
    }

    private func captureView(_ view: UIView, depth: Int, parentClass: String?) {
        if !showHidden && (view.isHidden || view.alpha < 0.01) { return }
        let cls = String(describing: type(of: view))
        if cls.hasPrefix("Phantom") { return }

        maxDepth = max(maxDepth, depth)
        let frame = view.convert(view.bounds, to: nil)

        // Skip zero-size views — UIGraphicsBeginImageContext crashes on {0,0}
        guard frame.width > 0 && frame.height > 0 &&
              view.bounds.width > 0 && view.bounds.height > 0 else {
            for sub in view.subviews {
                captureView(sub, depth: depth + 1, parentClass: cls)
            }
            return
        }

        // rasterize
        let snap = CALayer()
        snap.frame = CGRect(origin: .zero, size: frame.size)
        snap.isDoubleSided = false

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // 1x for performance
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
        let img = renderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
        snap.contents = img.cgImage

        let meta = SnapshotMeta(
            snapshotLayer: snap,
            sourceView: view,
            depth: depth,
            originalFrame: frame,
            className: cls,
            alpha: view.alpha,
            isHidden: view.isHidden,
            accessibilityID: view.accessibilityIdentifier,
            constraintCount: view.constraints.count,
            subviewCount: view.subviews.count,
            address: String(format: "%p", unsafeBitCast(view, to: Int.self)),
            parentClassName: parentClass,
            backgroundColor: view.backgroundColor
        )
        snapshots.append(meta)

        for sub in view.subviews {
            captureView(sub, depth: depth + 1, parentClass: cls)
        }
    }

    // MARK: - Build Scene
    // ──────────────────────────────────────────────────────────────────────

    private func rebuildScene(animated: Bool = false) {
        transformLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard !snapshots.isEmpty else { return }

        filteredIndices = snapshots.indices.filter {
            snapshots[$0].depth >= depthMin && snapshots[$0].depth <= depthMax
        }

        let rootFrame = snapshots.first?.originalFrame ?? .zero
        let cx = rootFrame.midX
        let cy = rootFrame.midY

        for (seq, idx) in filteredIndices.enumerated() {
            let meta = snapshots[idx]
            let wrapper = CATransformLayer()
            wrapper.isDoubleSided = false
            wrapper.name = "\(idx)"

            let layer = meta.snapshotLayer
            let relX = meta.originalFrame.origin.x - cx + meta.originalFrame.width / 2
            let relY = meta.originalFrame.origin.y - cy + meta.originalFrame.height / 2
            layer.position = CGPoint(x: relX, y: relY)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.bounds = CGRect(origin: .zero, size: meta.originalFrame.size)

            if isWireframe {
                layer.contents = nil
                layer.backgroundColor = UIColor.clear.cgColor
                layer.borderWidth = 1
                layer.borderColor = depthColor(meta.depth).withAlphaComponent(0.6).cgColor
            } else {
                layer.borderWidth = 0.5
                layer.borderColor = depthColor(meta.depth).withAlphaComponent(0.35).cgColor
            }

            // class name label layer
            if showLabels && meta.originalFrame.width > 20 && meta.originalFrame.height > 10 {
                let txt = CATextLayer()
                txt.string = meta.className
                txt.font = CTFontCreateWithName("Menlo-Bold" as CFString, 8, nil)
                txt.fontSize = 8
                txt.foregroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
                txt.backgroundColor = depthColor(meta.depth).withAlphaComponent(0.55).cgColor
                txt.cornerRadius = 3
                txt.alignmentMode = .center
                txt.contentsScale = UIScreen.main.scale
                txt.isWrapped = false
                let labelW = min(meta.originalFrame.width, CGFloat(meta.className.count) * 5.5 + 8)
                txt.frame = CGRect(x: relX - labelW / 2,
                                   y: relY - meta.originalFrame.height / 2 - 12,
                                   width: labelW, height: 14)
                txt.isDoubleSided = false
                wrapper.addSublayer(txt)
            }

            wrapper.addSublayer(layer)

            let zTarget = CGFloat(meta.depth) * spacing
            if animated {
                wrapper.transform = CATransform3DMakeTranslation(0, 0, 0)
                let anim = CABasicAnimation(keyPath: "transform")
                anim.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0, 0, 0))
                anim.toValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0, 0, zTarget))
                anim.duration = 0.5
                anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                anim.beginTime = CACurrentMediaTime() + Double(seq) * 0.008
                anim.fillMode = .forwards
                anim.isRemovedOnCompletion = false
                wrapper.add(anim, forKey: "entry")
            }
            wrapper.transform = CATransform3DMakeTranslation(0, 0, zTarget)

            transformLayer.addSublayer(wrapper)
        }

        applySelection()
        updateCamera()
        updateBadges()
        
        // On initial load, fit all layers to viewport
        // Delay to ensure layout is complete
        if animated && zoom == 1.0 && translateX == 0 && translateY == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.fitAllLayers()
            }
        }
    }

    // MARK: - Colors

    private func depthColor(_ depth: Int) -> UIColor {
        let palette: [UIColor] = [
            UIColor.Phantom.neonAzure,
            UIColor.Phantom.vibrantGreen,
            UIColor.Phantom.vibrantOrange,
            UIColor.Phantom.vibrantPurple,
            UIColor.Phantom.vibrantRed,
            UIColor.Phantom.vibrantTeal,
        ]
        return palette[depth % palette.count]
    }

    // MARK: - Camera
    // ──────────────────────────────────────────────────────────────────────

    private func updateCamera() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var t = CATransform3DIdentity
        t = CATransform3DScale(t, zoom, zoom, zoom)
        t = CATransform3DTranslate(t, translateX, translateY, 0)
        t = CATransform3DRotate(t, angleX, 1, 0, 0)
        t = CATransform3DRotate(t, angleY, 0, 1, 0)
        transformLayer.transform = t

        CATransaction.commit()
    }

    private func updateBadges() {
        countBadge.text = "\(filteredIndices.count)/\(snapshots.count) layers  ·  depth \(maxDepth)"
        zoomBadge.text = "\(Int(zoom * 100))%"
        spacingValueLabel.text = "\(Int(spacing))pt"
    }

    // MARK: - Selection & Highlight
    // ──────────────────────────────────────────────────────────────────────

    private func applySelection() {
        guard let wrappers = transformLayer.sublayers else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for wrapper in wrappers {
            guard let idxStr = wrapper.name, let idx = Int(idxStr),
                  idx < snapshots.count else { continue }
            // find the snapshot layer (last sublayer — labels come before it)
            guard let layer = wrapper.sublayers?.last else { continue }
            let meta = snapshots[idx]

            if let sel = selectedIndex {
                if idx == sel {
                    // Super bright glow effect for selected layer
                    layer.borderWidth = 3.0
                    layer.borderColor = UIColor.Phantom.neonAzure.cgColor
                    layer.opacity = 1.0
                    layer.shadowColor = UIColor.Phantom.neonAzure.cgColor
                    layer.shadowRadius = 16
                    layer.shadowOpacity = 0.95
                    layer.shadowOffset = .zero
                    
                    // Add outer glow via wrapper
                    wrapper.shadowColor = UIColor.Phantom.neonAzure.cgColor
                    wrapper.shadowRadius = 20
                    wrapper.shadowOpacity = 0.6
                    wrapper.shadowOffset = .zero
                } else {
                    layer.borderWidth = isWireframe ? 1 : 0.5
                    layer.borderColor = depthColor(meta.depth).withAlphaComponent(0.12).cgColor
                    layer.opacity = 0.15
                    layer.shadowOpacity = 0
                    wrapper.shadowOpacity = 0
                }
            } else {
                layer.borderWidth = isWireframe ? 1 : 0.5
                layer.borderColor = depthColor(meta.depth).withAlphaComponent(isWireframe ? 0.6 : 0.35).cgColor
                layer.opacity = 1.0
                layer.shadowOpacity = 0
                wrapper.shadowOpacity = 0
            }
        }
        CATransaction.commit()
    }

    // MARK: - Gestures
    // ──────────────────────────────────────────────────────────────────────

    private var panFingerCount = 0

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: sceneContainer)
        if g.state == .began { panFingerCount = g.numberOfTouches }

        if panFingerCount >= 2 {
            // 2-finger drag: orbit (rotate)
            angleY += t.x * 0.005
            angleX += t.y * 0.005
            angleX = max(-.pi / 2.2, min(.pi / 2.2, angleX))
        } else {
            // 1-finger drag: pan (translate) up/down/left/right
            translateX += t.x / zoom
            translateY += t.y / zoom
        }
        g.setTranslation(.zero, in: sceneContainer)
        updateCamera()
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        zoom *= g.scale
        zoom = max(0.1, min(10.0, zoom))
        g.scale = 1.0
        updateCamera()
        updateBadges()
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let pt = g.location(in: sceneContainer)
        var bestIdx: Int?
        var bestZ: CGFloat = -.greatestFiniteMagnitude

        guard let wrappers = transformLayer.sublayers else { return }
        for wrapper in wrappers {
            guard let idxStr = wrapper.name, let idx = Int(idxStr),
                  idx < snapshots.count,
                  let layer = wrapper.sublayers?.last else { continue }
            let converted = layer.convert(pt, from: sceneContainer.layer)
            if layer.contains(converted) {
                let z = CGFloat(snapshots[idx].depth) * spacing
                if z > bestZ { bestZ = z; bestIdx = idx }
            }
        }

        if let idx = bestIdx {
            selectedIndex = idx
            showInspector(for: snapshots[idx])
        } else {
            closeInspector()
        }
    }

    // MARK: - Actions
    // ──────────────────────────────────────────────────────────────────────

    @objc private func spacingDidChange() {
        spacing = CGFloat(spacingSlider.value)
        rebuildScene()
    }

    @objc private func depthDidChange() {
        depthMax = Int(depthRangeSlider.value)
        depthValueLabel.text = "≤ \(depthMax)"
        rebuildScene()
    }

    @objc private func rotateXDidChange() {
        angleX = CGFloat(rotateXSlider.value)
        rotateXValueLabel.text = "\(Int(angleX * 180 / CGFloat.pi))°"
        updateCamera()
    }

    @objc private func rotateYDidChange() {
        angleY = CGFloat(rotateYSlider.value)
        rotateYValueLabel.text = "\(Int(angleY * 180 / CGFloat.pi))°"
        updateCamera()
    }

    @objc private func toggleWireframe() {
        isWireframe.toggle()
        styleBtn(wireframeBtn, color: UIColor.Phantom.vibrantPurple, active: isWireframe)
        captureHierarchy()
        rebuildScene()
    }

    @objc private func toggleHidden() {
        showHidden.toggle()
        styleBtn(hiddenBtn, color: UIColor.Phantom.vibrantOrange, active: showHidden)
        captureHierarchy()
        rebuildScene()
    }

    @objc private func toggleLabels() {
        showLabels.toggle()
        styleBtn(labelsBtn, color: UIColor.Phantom.vibrantGreen, active: showLabels)
        rebuildScene()
    }

    @objc private func focusSelected() {
        guard let sel = selectedIndex else { return }
        let meta = snapshots[sel]
        // zoom & center on selected layer
        let rootFrame = snapshots.first?.originalFrame ?? .zero
        let relX = meta.originalFrame.midX - rootFrame.midX
        let relY = meta.originalFrame.midY - rootFrame.midY
        translateX = -relX
        translateY = -relY
        zoom = max(1.2, zoom)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75,
                       initialSpringVelocity: 0, options: [], animations: { [weak self] in
            self?.updateCamera()
            self?.updateBadges()
        })
    }

    @objc private func resetCamera() {
        angleX = -.pi / 9
        angleY = .pi / 12
        translateX = 0
        translateY = 0
        // Use proportional zoom based on root frame instead of hardcoded 1.0
        let rootFrame = snapshots.first?.originalFrame ?? .zero
        let viewportW = sceneContainer.bounds.width
        let viewportH = sceneContainer.bounds.height
        if rootFrame.width > 10 && rootFrame.height > 10 && viewportW > 0 && viewportH > 0 {
            let zoomW = viewportW / rootFrame.width
            let zoomH = viewportH / rootFrame.height
            zoom = max(0.2, min(5.0, min(zoomW, zoomH) * 0.85))
        } else {
            zoom = 1.0
        }
        // Sync rotation sliders
        rotateXSlider.value = Float(angleX)
        rotateYSlider.value = Float(angleY)
        rotateXValueLabel.text = "\(Int(angleX * 180 / CGFloat.pi))°"
        rotateYValueLabel.text = "\(Int(angleY * 180 / CGFloat.pi))°"
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.4)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        updateCamera()
        CATransaction.commit()
        updateBadges()
    }

    @objc private func fitAllLayers() {
        guard !filteredIndices.isEmpty else { return }
        
        // Use root view frame as reference — all layers are positioned relative to root center.
        // Using all-views bounding box causes zoom to be too small because off-screen views
        // (inside scroll views, table views) inflate the bounding box far beyond screen bounds.
        let rootFrame = snapshots.first?.originalFrame ?? .zero
        guard rootFrame.width > 10 && rootFrame.height > 10 else { return }
        
        let viewportW = sceneContainer.bounds.width
        let viewportH = sceneContainer.bounds.height
        guard viewportW > 0 && viewportH > 0 else { return }
        
        // Calculate zoom so root view fits in viewport with 15% margin
        let zoomW = viewportW / rootFrame.width
        let zoomH = viewportH / rootFrame.height
        let targetZoom = min(zoomW, zoomH) * 0.85
        
        // Center on root (layers already positioned relative to root center)
        translateX = 0
        translateY = 0
        zoom = max(0.2, min(5.0, targetZoom))
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        updateCamera()
        CATransaction.commit()
        updateBadges()
    }

    @objc private func dismissVC() {
        dismiss(animated: true)
    }

    // MARK: - UI Helpers
    // ──────────────────────────────────────────────────────────────────────

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func sliderRow(label: String, value: CGFloat, min: Float, max: Float,
                           color: UIColor, valueLbl: UILabel, slider: UISlider,
                           action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.5)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        row.addSubview(lbl)

        if #available(iOS 13.0, *) {
            valueLbl.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        } else {
            valueLbl.font = .systemFont(ofSize: 10, weight: .bold)
        }
        valueLbl.textColor = color
        valueLbl.textAlignment = .right
        valueLbl.translatesAutoresizingMaskIntoConstraints = false
        valueLbl.setContentHuggingPriority(.required, for: .horizontal)
        row.addSubview(valueLbl)

        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = Float(value)
        slider.tintColor = color
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: action, for: .valueChanged)
        row.addSubview(slider)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 52),

            slider.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 4),
            slider.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            valueLbl.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 4),
            valueLbl.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLbl.widthAnchor.constraint(equalToConstant: 40),
        ])
        return row
    }

    private func configBtn(_ btn: UIButton, title: String, color: UIColor, action: Selector) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        btn.addTarget(self, action: action, for: .touchUpInside)
        styleBtn(btn, color: color, active: false)
    }

    private func styleBtn(_ btn: UIButton, color: UIColor, active: Bool) {
        btn.tintColor = color
        btn.backgroundColor = active ? color.withAlphaComponent(0.2) : UIColor.white.withAlphaComponent(0.04)
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = active ? 1 : 0
        btn.layer.borderColor = active ? color.withAlphaComponent(0.5).cgColor : UIColor.clear.cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    }

    private func makePill(_ text: String, color: UIColor) -> UILabel {
        let lbl = UILabel()
        lbl.text = "  \(text)  "
        lbl.font = .systemFont(ofSize: 10, weight: .bold)
        lbl.textColor = color
        lbl.backgroundColor = color.withAlphaComponent(0.1)
        lbl.layer.cornerRadius = 6
        lbl.clipsToBounds = true
        lbl.textAlignment = .center
        return lbl
    }

    private func makeRow(label: String, value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        sep.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(sep)

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.4)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(lbl)

        let val = UILabel()
        val.text = value
        if #available(iOS 13.0, *) {
            val.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        } else {
            val.font = .systemFont(ofSize: 11, weight: .regular)
        }
        val.textColor = UIColor.white.withAlphaComponent(0.8)
        val.textAlignment = .right
        val.numberOfLines = 0
        val.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(val)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: row.topAnchor),
            sep.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            lbl.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 8),
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
            lbl.widthAnchor.constraint(equalToConstant: 100),

            val.centerYAnchor.constraint(equalTo: lbl.centerYAnchor),
            val.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            val.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        ])
        return row
    }

    private func describeColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        if a < 0.01 { return "clear" }
        return String(format: "rgba(%.0f,%.0f,%.0f,%.2f)", r * 255, g * 255, b * 255, a)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewHierarchy3DVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow pan + pinch to work simultaneously so 2-finger rotate works with zoom
        let isPanPinch = (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
            || (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
        return isPanPinch
    }
}

#endif
