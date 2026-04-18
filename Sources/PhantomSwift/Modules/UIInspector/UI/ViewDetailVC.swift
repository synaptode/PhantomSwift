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

        let bScrollView = setupBreadcrumbs(in: header)
        let (previewContainer, snapshotView) = setupSnapshotPreview(in: header)
        let typeLabel = setupTypeLabel(in: header)
        let addressLabel = setupAddressLabel(in: header)
        let infoRow = setupInfoPills(in: header)
        let actionsScrollView = setupActions(in: header)

        setupHeaderConstraints(
            header: header,
            bScrollView: bScrollView,
            previewContainer: previewContainer,
            snapshotView: snapshotView,
            typeLabel: typeLabel,
            addressLabel: addressLabel,
            infoRow: infoRow,
            actionsScrollView: actionsScrollView
        )

        tableView.tableHeaderView = header
    }

    private func setupBreadcrumbs(in header: UIView) -> UIScrollView {
        let bScrollView = UIScrollView()
        bScrollView.showsHorizontalScrollIndicator = false
        bScrollView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(bScrollView)

        breadcrumbStack.axis = .horizontal
        breadcrumbStack.spacing = 4
        breadcrumbStack.translatesAutoresizingMaskIntoConstraints = false
        bScrollView.addSubview(breadcrumbStack)
        buildBreadcrumbs()

        NSLayoutConstraint.activate([
            breadcrumbStack.topAnchor.constraint(equalTo: bScrollView.topAnchor),
            breadcrumbStack.bottomAnchor.constraint(equalTo: bScrollView.bottomAnchor),
            breadcrumbStack.leadingAnchor.constraint(equalTo: bScrollView.leadingAnchor),
            breadcrumbStack.trailingAnchor.constraint(equalTo: bScrollView.trailingAnchor),
            breadcrumbStack.heightAnchor.constraint(equalTo: bScrollView.heightAnchor)
        ])

        return bScrollView
    }

    private func setupSnapshotPreview(in header: UIView) -> (UIView, UIImageView) {
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
        return (previewContainer, snapshotView)
    }

    private func setupTypeLabel(in header: UIView) -> UILabel {
        let typeLabel = UILabel()
        typeLabel.text = String(describing: type(of: targetView)).uppercased()
        typeLabel.font = UIFont.systemFont(ofSize: 15, weight: .black)
        typeLabel.textColor = .white
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(typeLabel)
        return typeLabel
    }

    private func setupAddressLabel(in header: UIView) -> UILabel {
        let addressLabel = UILabel()
        addressLabel.text = "\(Unmanaged.passUnretained(targetView).toOpaque())"
        addressLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        addressLabel.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.6)
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(addressLabel)
        return addressLabel
    }

    private func setupInfoPills(in header: UIView) -> UIStackView {
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
        return infoRow
    }

    private func setupActions(in header: UIView) -> UIScrollView {
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

        let actions: [(String, String, UIColor, Selector)] = [
            ("Flash", "sparkles", UIColor.Phantom.vibrantOrange, #selector(flashTarget)),
            ("3D View", "cube", UIColor.Phantom.neonAzure, #selector(explodeTarget)),
            ("Live Edit", "slider.horizontal.3", UIColor.Phantom.vibrantGreen, #selector(showLiveEdit)),
            ("Audit", "accessibility", UIColor.Phantom.vibrantPurple, #selector(showAccessibilityAudit)),
            ("Gestures", "hand.tap", UIColor.Phantom.vibrantOrange, #selector(showGestureInspector)),
            ("Responder", "arrow.triangle.branch", UIColor.Phantom.neonAzure, #selector(showResponderChain)),
            ("Compare", "square.split.2x1", UIColor.Phantom.vibrantRed, #selector(showSnapshotCompare)),
            ("Layers", "square.stack.3d.up", UIColor.Phantom.vibrantPurple, #selector(showLayerInspector)),
            ("Constraints", "equal.circle", UIColor.Phantom.vibrantGreen, #selector(showConstraintInspector)),
            ("Animations", "waveform", UIColor.Phantom.neonAzure, #selector(showAnimationInspector)),
            ("Color Pick", "eyedropper.halffull", UIColor.Phantom.vibrantOrange, #selector(showColorPicker)),
            ("Grid", "squareshape.split.3x3", UIColor.Phantom.neonAzure, #selector(showGridOverlay)),
            ("Touch Viz", "hand.tap.fill", UIColor.Phantom.vibrantOrange, #selector(toggleTouchVisualizer)),
            ("Hit Test", "scope", UIColor.Phantom.vibrantGreen, #selector(showHitTestInspector)),
            ("Perf HUD", "flame.fill", UIColor.Phantom.vibrantOrange, #selector(togglePerfHUD)),
            ("Defaults", "tray.full.fill", UIColor.Phantom.vibrantGreen, #selector(showUserDefaultsInspector)),
            ("Env Override", "dial.min.fill", UIColor.Phantom.vibrantPurple, #selector(showEnvironmentOverride)),
            ("Export", "square.and.arrow.up", UIColor.white.withAlphaComponent(0.6), #selector(copyDescription))
        ]

        for (title, icon, color, action) in actions {
            let btn = createHeaderAction(title: title, icon: icon, color: color)
            btn.addTarget(self, action: action, for: .touchUpInside)
            actionsStack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: actionsScrollView.topAnchor),
            actionsStack.leadingAnchor.constraint(equalTo: actionsScrollView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsScrollView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsScrollView.bottomAnchor),
            actionsStack.heightAnchor.constraint(equalTo: actionsScrollView.heightAnchor)
        ])

        return actionsScrollView
    }

    private func setupHeaderConstraints(
        header: UIView,
        bScrollView: UIScrollView,
        previewContainer: UIView,
        snapshotView: UIImageView,
        typeLabel: UILabel,
        addressLabel: UILabel,
        infoRow: UIStackView,
        actionsScrollView: UIScrollView
    ) {
        NSLayoutConstraint.activate([
            bScrollView.topAnchor.constraint(equalTo: header.topAnchor, constant: 10),
            bScrollView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            {
                let c = bScrollView.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20)
                c.priority = .defaultHigh
                return c
            }(),
            bScrollView.heightAnchor.constraint(equalToConstant: 28),

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
            actionsScrollView.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -14)
        ])
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
        let hierarchyVC = ViewHierarchyVC(rootView: PhantomPresentationResolver.inspectedRootView(fallback: targetView))
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
