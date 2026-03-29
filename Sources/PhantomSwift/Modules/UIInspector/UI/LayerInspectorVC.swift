#if DEBUG
import UIKit

// MARK: - Layer Performance Model

private struct LayerPerf {
    let layer: CALayer
    let depth: Int
    let typeName: String
    let warnings: [LayerWarning]
    let isOpaque: Bool
    let opacity: Float
    let cornerRadius: CGFloat
    let shadowOpacity: Float

    struct LayerWarning {
        let text: String
        let level: Level
        enum Level { case expensive, moderate, info }

        var color: UIColor {
            switch level {
            case .expensive: return UIColor.Phantom.vibrantRed
            case .moderate:  return UIColor.Phantom.vibrantOrange
            case .info:      return UIColor.Phantom.neonAzure
            }
        }
        var icon: String {
            switch level {
            case .expensive: return "🔴"
            case .moderate:  return "🟡"
            case .info:      return "🔵"
            }
        }
    }
}

// MARK: - LayerInspectorVC

/// Recursively inspects the CALayer tree of a UIView, surfacing rendering cost warnings:
/// off-screen rendered shadows, rasterization, blended layers, masked corners, and more.
internal final class LayerInspectorVC: UIViewController {

    private let targetView: UIView
    private var nodes: [LayerPerf] = []
    private var expensiveCount  = 0
    private var moderateCount   = 0
    private let tableView       = UITableView(frame: .zero, style: .plain)

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Layer Inspector"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        applyNavBarStyle()
        buildNodes()
        setupTableView()
        setupNavItems()
    }

    // MARK: - NavBar

    private func applyNavBarStyle() {
        if #available(iOS 13.0, *) {
            let app = UINavigationBarAppearance()
            app.configureWithOpaqueBackground()
            app.backgroundColor = PhantomTheme.shared.backgroundColor
            app.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = app
            navigationController?.navigationBar.scrollEdgeAppearance = app
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }

    private func setupNavItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .plain, target: self, action: #selector(handleDone))
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain, target: self, action: #selector(exportReport))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Export", style: .plain, target: self, action: #selector(exportReport))
        }
    }

    // MARK: - Data

    private func buildNodes() {
        nodes.removeAll()
        expensiveCount = 0
        moderateCount  = 0
        traverse(layer: targetView.layer, depth: 0)
    }

    private func traverse(layer: CALayer, depth: Int) {
        let node = analyze(layer: layer, depth: depth)
        nodes.append(node)
        expensiveCount += node.warnings.filter { $0.level == .expensive }.count
        moderateCount  += node.warnings.filter { $0.level == .moderate  }.count
        layer.sublayers?.forEach { traverse(layer: $0, depth: depth + 1) }
    }

    private func analyze(layer: CALayer, depth: Int) -> LayerPerf {
        var warnings: [LayerPerf.LayerWarning] = []

        // 🔴 Off-screen rendering: shadow without rasterization
        if layer.shadowOpacity > 0 && !layer.shouldRasterize {
            warnings.append(.init(
                text: "Shadow without rasterization → expensive off-screen pass",
                level: .expensive))
        }

        // 🔴 Large shadow blur
        if layer.shadowOpacity > 0 && layer.shadowRadius > 12 {
            warnings.append(.init(
                text: "Shadow radius \(layer.shadowRadius) is very large (GPU fill area scales quadratically)",
                level: .expensive))
        }

        // 🔴 Group opacity compositing
        if layer.allowsGroupOpacity && layer.opacity < 0.99 && layer.opacity > 0 {
            warnings.append(.init(
                text: "Group opacity (\(String(format: "%.2f", layer.opacity))) triggers off-screen compositing",
                level: .expensive))
        }

        // 🟡 Rasterized layer
        if layer.shouldRasterize {
            warnings.append(.init(
                text: "Rasterized — cheap for static content, expensive if layer changes every frame",
                level: .moderate))
        }

        // 🟡 Masked corners (pre-iOS 13 triggers off-screen)
        if layer.cornerRadius > 0 && layer.masksToBounds {
            let note = "Masked cornerRadius \(Int(layer.cornerRadius)) — off-screen render on iOS < 13"
            warnings.append(.init(text: note, level: .moderate))
        }

        // 🟡 Non-opaque layer
        if !layer.isOpaque && layer.opacity > 0 {
            warnings.append(.init(
                text: "Non-opaque layer — GPU must alpha-blend with content below",
                level: .moderate))
        }

        // 🔵 CAGradientLayer
        if layer is CAGradientLayer {
            warnings.append(.init(text: "Gradient layer — recalculated each frame if animated", level: .info))
        }

        // 🔵 CAShapeLayer
        if layer is CAShapeLayer {
            warnings.append(.init(text: "Shape layer — CPU rasterized, avoid animating path", level: .info))
        }

        // 🔵 CAEmitterLayer
        if layer is CAEmitterLayer {
            warnings.append(.init(text: "Emitter (particle system) — GPU heavy, profile carefully", level: .info))
        }

        // 🔵 CAReplicatorLayer
        if layer is CAReplicatorLayer {
            warnings.append(.init(text: "Replicator layer — N copies rendered each frame", level: .info))
        }

        // Determine type name
        let typeName: String
        switch layer {
        case is CAGradientLayer:  typeName = "CAGradientLayer"
        case is CAShapeLayer:     typeName = "CAShapeLayer"
        case is CAEmitterLayer:   typeName = "CAEmitterLayer"
        case is CATextLayer:      typeName = "CATextLayer"
        case is CAReplicatorLayer: typeName = "CAReplicatorLayer"
        default:                  typeName = "CALayer"
        }

        return LayerPerf(
            layer: layer,
            depth: depth,
            typeName: typeName,
            warnings: warnings,
            isOpaque: layer.isOpaque,
            opacity: layer.opacity,
            cornerRadius: layer.cornerRadius,
            shadowOpacity: layer.shadowOpacity)
    }

    // MARK: - Table

    private func setupTableView() {
        setupHeader()
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(LayerPerfCell.self, forCellReuseIdentifier: "LayerPerfCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupHeader() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 88))
        header.backgroundColor = PhantomTheme.shared.surfaceColor

        let totalLbl = makeScorePill(
            text: "\(nodes.count) layers",
            color: UIColor.Phantom.neonAzure)
        let expLbl = makeScorePill(
            text: "🔴 \(expensiveCount) expensive",
            color: UIColor.Phantom.vibrantRed)
        let modLbl = makeScorePill(
            text: "🟡 \(moderateCount) moderate",
            color: UIColor.Phantom.vibrantOrange)

        let stack = UIStackView(arrangedSubviews: [totalLbl, expLbl, modLbl])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)

        let hint = UILabel()
        hint.text = "Tap a layer to highlight it in the hierarchy"
        hint.font = .systemFont(ofSize: 10, weight: .medium)
        hint.textColor = UIColor.white.withAlphaComponent(0.25)
        hint.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(hint)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            stack.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            hint.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 8),
            hint.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12)
        ])

        tableView.tableHeaderView = header
    }

    private func makeScorePill(text: String, color: UIColor) -> UILabel {
        let lbl = UILabel()
        lbl.text = "  \(text)  "
        lbl.font = .systemFont(ofSize: 11, weight: .black)
        lbl.textColor = color
        lbl.backgroundColor = color.withAlphaComponent(0.1)
        lbl.layer.cornerRadius = 10
        lbl.layer.masksToBounds = true
        lbl.textAlignment = .center
        return lbl
    }

    // MARK: - Actions

    @objc private func handleDone() { dismiss(animated: true) }

    @objc private func exportReport() {
        var lines = [
            "Layer Inspector — \(type(of: targetView))",
            "Layers: \(nodes.count)  Expensive: \(expensiveCount)  Moderate: \(moderateCount)",
            ""
        ]
        for node in nodes {
            let indent = String(repeating: "  ", count: node.depth)
            lines.append("\(indent)[\(node.typeName)]  opacity:\(node.opacity)  opaque:\(node.isOpaque)")
            for w in node.warnings {
                lines.append("\(indent)  \(w.icon) \(w.text)")
            }
        }
        let vc = UIActivityViewController(
            activityItems: [lines.joined(separator: "\n")],
            applicationActivities: nil)
        present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource, Delegate

extension LayerInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        nodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "LayerPerfCell", for: indexPath) as! LayerPerfCell
        cell.configure(with: nodes[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 80 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let node = nodes[indexPath.row]
        flashLayer(node.layer)
    }

    private func flashLayer(_ layer: CALayer) {
        let original = layer.borderColor
        let originalWidth = layer.borderWidth
        layer.borderColor  = UIColor.Phantom.vibrantOrange.cgColor
        layer.borderWidth  = 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            layer.borderColor = original
            layer.borderWidth = originalWidth
        }
    }
}

// MARK: - LayerPerfCell

private final class LayerPerfCell: UITableViewCell {

    private let indentLine   = UIView()
    private let typeLabel    = UILabel()
    private let propsLabel   = UILabel()
    private let warningStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        indentLine.layer.cornerRadius = 1.5
        indentLine.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.3)
        indentLine.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(indentLine)

        typeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        typeLabel.textColor = .white
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)

        propsLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        propsLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        propsLabel.numberOfLines = 1
        propsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(propsLabel)

        warningStack.axis = .vertical
        warningStack.spacing = 3
        warningStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(warningStack)

        NSLayoutConstraint.activate([
            indentLine.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            indentLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            indentLine.widthAnchor.constraint(equalToConstant: 3),
            indentLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            typeLabel.leadingAnchor.constraint(equalTo: indentLine.trailingAnchor, constant: 12),
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            propsLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            propsLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            propsLabel.trailingAnchor.constraint(equalTo: typeLabel.trailingAnchor),

            warningStack.topAnchor.constraint(equalTo: propsLabel.bottomAnchor, constant: 6),
            warningStack.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            warningStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            warningStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with node: LayerPerf) {
        // Indent line color by severity
        if node.warnings.contains(where: { $0.level == .expensive }) {
            indentLine.backgroundColor = UIColor.Phantom.vibrantRed
        } else if node.warnings.contains(where: { $0.level == .moderate }) {
            indentLine.backgroundColor = UIColor.Phantom.vibrantOrange
        } else {
            indentLine.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.3)
        }

        let depthPrefix = String(repeating: "  ", count: node.depth)
        typeLabel.text = "\(depthPrefix)\(node.typeName)"

        let props = "opacity: \(String(format: "%.2f", node.opacity))  " +
                    "opaque: \(node.isOpaque)  " +
                    "shadow: \(String(format: "%.2f", node.shadowOpacity))  " +
                    "cornerR: \(Int(node.cornerRadius))"
        propsLabel.text = depthPrefix + props

        warningStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for w in node.warnings {
            warningStack.addArrangedSubview(makeWarningBadge(w))
        }
    }

    private func makeWarningBadge(_ w: LayerPerf.LayerWarning) -> UIView {
        let container = UIView()
        container.backgroundColor = w.color.withAlphaComponent(0.08)
        container.layer.cornerRadius = 6
        container.layer.borderWidth  = 0.5
        container.layer.borderColor  = w.color.withAlphaComponent(0.3).cgColor

        let lbl = UILabel()
        lbl.text = "\(w.icon) \(w.text)"
        lbl.font = .systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = w.color
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            lbl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            lbl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }
}

#endif
