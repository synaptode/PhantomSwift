#if DEBUG
import UIKit

/// Displays properties of a selected view with modern card-based sections,
/// live toggles, color swatches, breadcrumb navigation, and snapshot preview.
internal final class ViewDetailVC: PhantomTableVC {
    private let targetView: UIView
    private var sections: [(title: String, rows: [PropertyRow])] = []
    private var allSections: [(title: String, rows: [PropertyRow])] = []
    private var breadcrumbStack = UIStackView()
    private var actionsStack = UIStackView()

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Properties"

        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure

        setupNavigation()
        setupHeader()
        buildSections()

        tableView.register(PropertyCell.self, forCellReuseIdentifier: "PropertyCell")
        searchBar.delegate = self
        searchBar.placeholder = "Filter properties..."
    }

    // MARK: - Header

    private func setupHeader() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 250))
        header.backgroundColor = .clear

        // Breadcrumbs
        let bScrollView = UIScrollView()
        bScrollView.showsHorizontalScrollIndicator = false
        bScrollView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(bScrollView)

        breadcrumbStack.axis = .horizontal
        breadcrumbStack.spacing = 4
        breadcrumbStack.translatesAutoresizingMaskIntoConstraints = false
        bScrollView.addSubview(breadcrumbStack)
        buildBreadcrumbs()

        // Snapshot Preview
        let previewContainer = UIView()
        previewContainer.backgroundColor = PhantomTheme.shared.surfaceColor
        previewContainer.layer.cornerRadius = 14
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        previewContainer.clipsToBounds = true
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(previewContainer)

        let snapshot: UIImage?
        if targetView.bounds.width > 0 && targetView.bounds.height > 0 {
            snapshot = targetView.snapshot()
        } else {
            snapshot = nil
        }

        let snapshotView = UIImageView(image: snapshot)
        snapshotView.contentMode = .scaleAspectFit
        snapshotView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(snapshotView)

        // Type + Address
        let typeLabel = UILabel()
        typeLabel.text = String(describing: type(of: targetView)).uppercased()
        typeLabel.font = UIFont.systemFont(ofSize: 15, weight: .black)
        typeLabel.textColor = .white
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(typeLabel)

        let addressLabel = UILabel()
        addressLabel.text = "\(Unmanaged.passUnretained(targetView).toOpaque())"
        addressLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        addressLabel.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.6)
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(addressLabel)

        // Quick info pills
        let infoRow = UIStackView()
        infoRow.axis = .horizontal
        infoRow.spacing = 8
        infoRow.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(infoRow)

        let framePill = makeInfoPill(
            text: String(format: "%.0fx%.0f", targetView.frame.width, targetView.frame.height),
            color: UIColor.Phantom.vibrantGreen)
        let depthPill = makeInfoPill(
            text: "\(countDepth(targetView))d",
            color: UIColor.Phantom.vibrantPurple)
        let subPill = makeInfoPill(
            text: "\(targetView.subviews.count) sub",
            color: UIColor.Phantom.vibrantOrange)
        [framePill, depthPill, subPill].forEach { infoRow.addArrangedSubview($0) }

        // Actions — scrollable row of buttons
        let actionsScrollView = UIScrollView()
        actionsScrollView.showsHorizontalScrollIndicator = false
        actionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(actionsScrollView)

        actionsStack.axis = .horizontal
        actionsStack.spacing = 8
        actionsStack.distribution = .fill
        actionsStack.alignment = .center
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsScrollView.addSubview(actionsStack)

        let flashBtn = createHeaderAction(title: "Flash", icon: "sparkles", color: UIColor.Phantom.vibrantOrange)
        flashBtn.addTarget(self, action: #selector(flashTarget), for: .touchUpInside)
        actionsStack.addArrangedSubview(flashBtn)

        let explodeBtn = createHeaderAction(title: "3D View", icon: "cube", color: UIColor.Phantom.neonAzure)
        explodeBtn.addTarget(self, action: #selector(explodeTarget), for: .touchUpInside)
        actionsStack.addArrangedSubview(explodeBtn)

        let editBtn = createHeaderAction(title: "Live Edit", icon: "slider.horizontal.3", color: UIColor.Phantom.vibrantGreen)
        editBtn.addTarget(self, action: #selector(showLiveEdit), for: .touchUpInside)
        actionsStack.addArrangedSubview(editBtn)

        let a11yBtn = createHeaderAction(title: "Audit", icon: "accessibility", color: UIColor.Phantom.vibrantPurple)
        a11yBtn.addTarget(self, action: #selector(showAccessibilityAudit), for: .touchUpInside)
        actionsStack.addArrangedSubview(a11yBtn)

        let gestureBtn = createHeaderAction(title: "Gestures", icon: "hand.tap", color: UIColor.Phantom.vibrantOrange)
        gestureBtn.addTarget(self, action: #selector(showGestureInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(gestureBtn)

        let responderBtn = createHeaderAction(title: "Responder", icon: "arrow.triangle.branch", color: UIColor.Phantom.neonAzure)
        responderBtn.addTarget(self, action: #selector(showResponderChain), for: .touchUpInside)
        actionsStack.addArrangedSubview(responderBtn)

        let compareBtn = createHeaderAction(title: "Compare", icon: "square.split.2x1", color: UIColor.Phantom.vibrantRed)
        compareBtn.addTarget(self, action: #selector(showSnapshotCompare), for: .touchUpInside)
        actionsStack.addArrangedSubview(compareBtn)

        let layerBtn = createHeaderAction(title: "Layers", icon: "square.stack.3d.up", color: UIColor.Phantom.vibrantPurple)
        layerBtn.addTarget(self, action: #selector(showLayerInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(layerBtn)

        let constraintBtn = createHeaderAction(title: "Constraints", icon: "equal.circle", color: UIColor.Phantom.vibrantGreen)
        constraintBtn.addTarget(self, action: #selector(showConstraintInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(constraintBtn)

        let animBtn = createHeaderAction(title: "Animations", icon: "waveform", color: UIColor.Phantom.neonAzure)
        animBtn.addTarget(self, action: #selector(showAnimationInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(animBtn)

        let colorBtn = createHeaderAction(title: "Color Pick", icon: "eyedropper.halffull", color: UIColor.Phantom.vibrantOrange)
        colorBtn.addTarget(self, action: #selector(showColorPicker), for: .touchUpInside)
        actionsStack.addArrangedSubview(colorBtn)

        let gridBtn = createHeaderAction(title: "Grid", icon: "squareshape.split.3x3", color: UIColor.Phantom.neonAzure)
        gridBtn.addTarget(self, action: #selector(showGridOverlay), for: .touchUpInside)
        actionsStack.addArrangedSubview(gridBtn)

        let touchBtn = createHeaderAction(title: "Touch Viz", icon: "hand.tap.fill", color: UIColor.Phantom.vibrantOrange)
        touchBtn.addTarget(self, action: #selector(toggleTouchVisualizer), for: .touchUpInside)
        actionsStack.addArrangedSubview(touchBtn)

        let hitBtn = createHeaderAction(title: "Hit Test", icon: "scope", color: UIColor.Phantom.vibrantGreen)
        hitBtn.addTarget(self, action: #selector(showHitTestInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(hitBtn)

        let perfBtn = createHeaderAction(title: "Perf HUD", icon: "flame.fill", color: UIColor.Phantom.vibrantOrange)
        perfBtn.addTarget(self, action: #selector(togglePerfHUD), for: .touchUpInside)
        actionsStack.addArrangedSubview(perfBtn)

        let defaultsBtn = createHeaderAction(title: "Defaults", icon: "tray.full.fill", color: UIColor.Phantom.vibrantGreen)
        defaultsBtn.addTarget(self, action: #selector(showUserDefaultsInspector), for: .touchUpInside)
        actionsStack.addArrangedSubview(defaultsBtn)

        let envBtn = createHeaderAction(title: "Env Override", icon: "dial.min.fill", color: UIColor.Phantom.vibrantPurple)
        envBtn.addTarget(self, action: #selector(showEnvironmentOverride), for: .touchUpInside)
        actionsStack.addArrangedSubview(envBtn)

        let copyBtn = createHeaderAction(title: "Export", icon: "square.and.arrow.up", color: UIColor.white.withAlphaComponent(0.6))
        copyBtn.addTarget(self, action: #selector(copyDescription), for: .touchUpInside)
        actionsStack.addArrangedSubview(copyBtn)

        NSLayoutConstraint.activate([
            bScrollView.topAnchor.constraint(equalTo: header.topAnchor, constant: 10),
            bScrollView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            {
                let c = bScrollView.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20)
                c.priority = .defaultHigh
                return c
            }(),
            bScrollView.heightAnchor.constraint(equalToConstant: 28),

            breadcrumbStack.topAnchor.constraint(equalTo: bScrollView.topAnchor),
            breadcrumbStack.bottomAnchor.constraint(equalTo: bScrollView.bottomAnchor),
            breadcrumbStack.leadingAnchor.constraint(equalTo: bScrollView.leadingAnchor),
            breadcrumbStack.trailingAnchor.constraint(equalTo: bScrollView.trailingAnchor),
            breadcrumbStack.heightAnchor.constraint(equalTo: bScrollView.heightAnchor),

            previewContainer.topAnchor.constraint(equalTo: bScrollView.bottomAnchor, constant: 14),
            previewContainer.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            previewContainer.widthAnchor.constraint(equalToConstant: 64),
            previewContainer.heightAnchor.constraint(equalToConstant: 64),

            snapshotView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            snapshotView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -8),
            snapshotView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            snapshotView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),

            typeLabel.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 10),
            typeLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),

            addressLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            addressLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),

            infoRow.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 8),
            infoRow.centerXAnchor.constraint(equalTo: header.centerXAnchor),

            actionsScrollView.topAnchor.constraint(equalTo: infoRow.bottomAnchor, constant: 12),
            actionsScrollView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            actionsScrollView.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            actionsScrollView.heightAnchor.constraint(equalToConstant: 34),
            actionsScrollView.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -14),
            actionsStack.topAnchor.constraint(equalTo: actionsScrollView.topAnchor),
            actionsStack.leadingAnchor.constraint(equalTo: actionsScrollView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsScrollView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsScrollView.bottomAnchor),
            actionsStack.heightAnchor.constraint(equalTo: actionsScrollView.heightAnchor),
        ])

        tableView.tableHeaderView = header
    }

    private func makeInfoPill(text: String, color: UIColor) -> UIView {
        let lbl = UILabel()
        lbl.text = "  \(text)  "
        lbl.font = .monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        lbl.textColor = color
        lbl.backgroundColor = color.withAlphaComponent(0.1)
        lbl.layer.cornerRadius = 8
        lbl.layer.masksToBounds = true
        lbl.textAlignment = .center
        lbl.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return lbl
    }

    private func countDepth(_ view: UIView) -> Int {
        var d = 0; var v: UIView? = view
        while let s = v?.superview { d += 1; v = s }
        return d
    }

    private func createHeaderAction(title: String, icon: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            btn.setImage(UIImage(systemName: icon)?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        }
        btn.setTitle(" " + title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        btn.tintColor = color
        btn.backgroundColor = color.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 12
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return btn
    }

    // MARK: - Actions

    @objc private func showLiveEdit() {
        let editVC = LiveEditVC(targetView: targetView)
        navigationController?.pushViewController(editVC, animated: true)
    }

    @objc private func showAccessibilityAudit() {
        let auditVC = AccessibilityAuditVC(rootView: targetView)
        navigationController?.pushViewController(auditVC, animated: true)
    }

    @objc private func showGestureInspector() {
        let gestureVC = GestureInspectorVC(targetView: targetView)
        navigationController?.pushViewController(gestureVC, animated: true)
    }

    @objc private func showResponderChain() {
        let responderVC = ResponderChainVC(targetView: targetView)
        navigationController?.pushViewController(responderVC, animated: true)
    }

    @objc private func showSnapshotCompare() {
        let compareVC = SnapshotCompareVC(targetView: targetView)
        navigationController?.pushViewController(compareVC, animated: true)
    }

    @objc private func showLayerInspector() {
        let layerVC = LayerInspectorVC(targetView: targetView)
        navigationController?.pushViewController(layerVC, animated: true)
    }

    @objc private func showConstraintInspector() {
        let constraintVC = ConstraintInspectorVC(targetView: targetView)
        navigationController?.pushViewController(constraintVC, animated: true)
    }

    @objc private func showAnimationInspector() {
        let animVC = AnimationInspectorVC(targetView: targetView)
        navigationController?.pushViewController(animVC, animated: true)
    }

    @objc private func showColorPicker() {
        guard let screenshot = UIView.captureAppWindow() else { return }
        let picker = ColorPickerVC(screenshot: screenshot)
        picker.onColorPicked = { [weak self] color, hex in
            self?.showToast("\(hex) copied")
        }
        present(picker, animated: false)
    }

    @objc private func showGridOverlay() {
        let gridVC = GridOverlayVC()
        let nav = UINavigationController(rootViewController: gridVC)
        nav.modalPresentationStyle = .overFullScreen
        present(nav, animated: true)
    }

    @objc private func toggleTouchVisualizer() {
        PhantomUIInspector.shared.toggleTouchVisualizer()
        showToast(PhantomTouchVisualizer.shared.isActive ? "Touch Visualizer ON" : "Touch Visualizer OFF")
    }

    @objc private func showHitTestInspector() {
        PhantomUIInspector.shared.showHitTestInspector()
    }

    @objc private func togglePerfHUD() {
        PhantomFPSMonitor.shared.toggle()
        showToast(PhantomFPSMonitor.shared.isRunning ? "Perf HUD ON" : "Perf HUD OFF")
    }

    @objc private func showUserDefaultsInspector() {
        let vc = UserDefaultsInspectorVC()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        present(nav, animated: true)
    }

    @objc private func showEnvironmentOverride() {
        let vc = EnvironmentOverrideVC()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        present(nav, animated: true)
    }

    @objc private func flashTarget() {
        let originalColor = targetView.backgroundColor
        UIView.animate(withDuration: 0.15, animations: {
            self.targetView.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.8)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.targetView.backgroundColor = originalColor
            }
        }
    }

    @objc private func explodeTarget() {
        let explodeVC = ViewHierarchy3DVC(rootView: targetView)
        navigationController?.pushViewController(explodeVC, animated: true)
    }

    @objc private func copyDescription() {
        let desc = """
        \(type(of: targetView))
        Frame: \(targetView.frame)
        Bounds: \(targetView.bounds)
        Alpha: \(targetView.alpha)
        Hidden: \(targetView.isHidden)
        Subviews: \(targetView.subviews.count)
        Constraints: \(targetView.constraints.count)
        """
        UIPasteboard.general.string = desc
        showToast("Copied!")
    }

    private func showToast(_ text: String) {
        let toast = UILabel()
        toast.text = "  \(text)  "
        toast.font = .systemFont(ofSize: 12, weight: .bold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.layer.masksToBounds = true
        toast.textAlignment = .center
        toast.alpha = 0
        view.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 30),
        ])
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissInspector))
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "list.bullet.indent"),
                style: .plain, target: self, action: #selector(showHierarchy))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Hierarchy", style: .plain, target: self, action: #selector(showHierarchy))
        }
    }

    @objc private func dismissInspector() {
        self.dismiss(animated: true) {
            PhantomUIInspector.shared.stopInspecting()
        }
    }

    @objc private func showHierarchy() {
        let hierarchyVC = ViewHierarchyVC(rootView: UIApplication.shared.keyWindow ?? targetView)
        navigationController?.pushViewController(hierarchyVC, animated: true)
    }

    // MARK: - Breadcrumbs

    private func buildBreadcrumbs() {
        breadcrumbStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var current: UIView? = targetView
        var path: [UIView] = []
        while let v = current { path.insert(v, at: 0); current = v.superview }

        for (index, view) in path.enumerated() {
            let isLast = index == path.count - 1
            let btn = UIButton(type: .system)
            btn.setTitle(String(describing: type(of: view)), for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: isLast ? .black : .medium)
            btn.tintColor = isLast ? .white : UIColor.Phantom.neonAzure.withAlphaComponent(0.6)
            if isLast {
                btn.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.15)
                btn.layer.cornerRadius = 8
                btn.contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
            }
            btn.tag = index
            btn.addTarget(self, action: #selector(breadcrumbTapped(_:)), for: .touchUpInside)
            breadcrumbStack.addArrangedSubview(btn)

            if !isLast {
                let arrow = UILabel()
                arrow.text = ">"
                arrow.font = UIFont.systemFont(ofSize: 8, weight: .bold)
                arrow.textColor = UIColor.white.withAlphaComponent(0.15)
                breadcrumbStack.addArrangedSubview(arrow)
            }
        }
    }

    @objc private func breadcrumbTapped(_ sender: UIButton) {
        var current: UIView? = targetView
        var path: [UIView] = []
        while let v = current { path.insert(v, at: 0); current = v.superview }
        guard sender.tag < path.count else { return }
        let newDetail = ViewDetailVC(targetView: path[sender.tag])
        navigationController?.pushViewController(newDetail, animated: true)
    }

    // MARK: - Sections

    private func buildSections() {
        let constraints = targetView.constraints
            .compactMap { $0.isActive ? PropertyRow(name: "Constraint", value: "Const: \($0.constant)", type: .info) : nil }

        var geoRows = [
            PropertyRow(name: "Frame", value: "\(targetView.frame)", type: .info),
            PropertyRow(name: "Bounds", value: "\(targetView.bounds)", type: .info),
            PropertyRow(name: "Center", value: "\(targetView.center)", type: .info)
        ]
        if #available(iOS 11.0, *) {
            geoRows.append(PropertyRow(name: "Safe Area", value: "\(targetView.safeAreaInsets)", type: .info))
        }

        allSections = [
            ("Geometry", geoRows),
            ("Layer (Visuals)", [
                PropertyRow(name: "Corner Radius", value: "\(targetView.layer.cornerRadius)", type: .info),
                PropertyRow(name: "Border Width", value: "\(targetView.layer.borderWidth)", type: .info),
                PropertyRow(name: "Shadow Opacity", value: "\(targetView.layer.shadowOpacity)", type: .info),
                PropertyRow(name: "Shadow Radius", value: "\(targetView.layer.shadowRadius)", type: .info),
                PropertyRow(name: "Masks to Bounds", value: "\(targetView.layer.masksToBounds)", type: .toggle)
            ]),
            ("Colors", [
                PropertyRow(name: "Background", value: targetView.backgroundColor?.hexString ?? "None", type: .info),
                PropertyRow(name: "Tint", value: targetView.tintColor?.hexString ?? "None", type: .info),
                PropertyRow(name: "Border", value: targetView.layer.borderColor != nil ? UIColor(cgColor: targetView.layer.borderColor!).hexString : "None", type: .info)
            ]),
            ("Visual State", [
                PropertyRow(name: "Alpha", value: String(format: "%.2f", targetView.alpha), type: .info),
                PropertyRow(name: "Hidden", value: "\(targetView.isHidden)", type: .toggle),
                PropertyRow(name: "Clip to Bounds", value: "\(targetView.clipsToBounds)", type: .toggle),
                PropertyRow(name: "User Interaction", value: "\(targetView.isUserInteractionEnabled)", type: .toggle)
            ]),
            ("Accessibility", [
                PropertyRow(name: "Identifier", value: targetView.accessibilityIdentifier ?? "None", type: .info),
                PropertyRow(name: "Label", value: targetView.accessibilityLabel ?? "None", type: .info),
                PropertyRow(name: "Hint", value: targetView.accessibilityHint ?? "None", type: .info)
            ]),
            ("Auto Layout", constraints.isEmpty ? [PropertyRow(name: "None", value: "No constraints", type: .info)] : constraints),
            ("Hierarchy", [
                PropertyRow(name: "Subviews", value: "\(targetView.subviews.count)", type: .info),
                PropertyRow(name: "Superview", value: "\(type(of: targetView.superview ?? UIView()))", type: .info),
                PropertyRow(name: "Tag", value: "\(targetView.tag)", type: .info)
            ])
        ]
        sections = allSections
        tableView.reloadData()
    }

    // MARK: - TableView

    override func numberOfSections(in tableView: UITableView) -> Int { return sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = PhantomTheme.shared.backgroundColor

        let lbl = UILabel()
        lbl.text = sections[section].title.uppercased()
        lbl.font = .systemFont(ofSize: 10, weight: .black)
        lbl.textColor = UIColor.white.withAlphaComponent(0.35)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            lbl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return 32 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyCell
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.configure(with: row)
        cell.onToggle = { [weak self] isOn in
            self?.handlePropertyChange(name: row.name, isOn: isOn)
        }
        return cell
    }

    private func handlePropertyChange(name: String, isOn: Bool) {
        switch name {
        case "Hidden": targetView.isHidden = isOn
        case "Clip to Bounds": targetView.clipsToBounds = isOn
        case "User Interaction": targetView.isUserInteractionEnabled = isOn
        case "Masks to Bounds": targetView.layer.masksToBounds = isOn
        default: break
        }
    }
}

// MARK: - Search

extension ViewDetailVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            sections = allSections
        } else {
            sections = allSections.compactMap { section in
                let filteredRows = section.rows.filter { $0.name.lowercased().contains(searchText.lowercased()) }
                return filteredRows.isEmpty ? nil : (title: section.title, rows: filteredRows)
            }
        }
        tableView.reloadData()
    }
}

// MARK: - Color Helpers

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
        return "#FFFFFF"
    }

    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Supporting Types

private enum PropertyType { case info, toggle }

private struct PropertyRow {
    let name: String
    let value: String
    let type: PropertyType
}

private final class PropertyCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let toggle = UISwitch()
    private let colorSwatch = UIView()
    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(titleLabel)

        valueLabel.textColor = UIColor.Phantom.neonAzure
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2
        valueLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(valueLabel)

        colorSwatch.layer.cornerRadius = 6
        colorSwatch.layer.borderWidth = 1
        colorSwatch.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        colorSwatch.isHidden = true
        contentView.addSubview(colorSwatch)

        toggle.onTintColor = UIColor.Phantom.neonAzure
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        contentView.addSubview(toggle)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        colorSwatch.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
            valueLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),

            colorSwatch.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            colorSwatch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorSwatch.widthAnchor.constraint(equalToConstant: 14),
            colorSwatch.heightAnchor.constraint(equalToConstant: 14),

            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    func configure(with row: PropertyRow) {
        titleLabel.text = row.name
        valueLabel.text = row.value

        if row.value.starts(with: "#") {
            colorSwatch.isHidden = false
            colorSwatch.backgroundColor = UIColor(hex: row.value)
        } else {
            colorSwatch.isHidden = true
        }

        switch row.type {
        case .info:
            valueLabel.isHidden = false
            toggle.isHidden = true
        case .toggle:
            valueLabel.isHidden = true
            toggle.isHidden = false
            toggle.isOn = row.value == "true"
        }
    }

    @objc private func toggleChanged() { onToggle?(toggle.isOn) }
}
#endif
