#if DEBUG
import UIKit

// MARK: - Tree Node Model

private final class TreeNode {
    let view: UIView
    let depth: Int
    let className: String
    var isExpanded: Bool = true
    var children: [TreeNode] = []

    init(view: UIView, depth: Int) {
        self.view = view
        self.depth = depth
        self.className = String(describing: type(of: view))
    }
}

/// Modern hierarchical tree view with collapsible nodes, search, depth indicators,
/// view count badges, and colored depth lines.
internal final class ViewHierarchyVC: PhantomTableVC {
    private let rootView: UIView
    private var rootNode: TreeNode?
    private var flatList: [(node: TreeNode, visible: Bool)] = []
    private var displayList: [TreeNode] = []
    private var searchText: String = ""
    private var totalViewCount: Int = 0

    internal init(rootView: UIView) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "View Hierarchy"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigation()
        buildTree()
        rebuildDisplayList()

        tableView.separatorStyle = .none
        tableView.register(HierarchyNodeCell.self, forCellReuseIdentifier: "HierarchyNodeCell")
        searchBar.delegate = self
        searchBar.placeholder = "Filter views..."

        setupFooter()
    }

    // MARK: - Nav

    private func setupNavigation() {
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

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .plain, target: self, action: #selector(dismissHierarchy))

        if #available(iOS 13.0, *) {
            let threeD = UIBarButtonItem(
                image: UIImage(systemName: "cube"),
                style: .plain, target: self, action: #selector(show3D))
            let collapse = UIBarButtonItem(
                image: UIImage(systemName: "arrow.down.right.and.arrow.up.left"),
                style: .plain, target: self, action: #selector(collapseAll))
            let expand = UIBarButtonItem(
                image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"),
                style: .plain, target: self, action: #selector(expandAll))
            let export = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain, target: self, action: #selector(exportHierarchy))
            navigationItem.rightBarButtonItems = [threeD, expand, collapse, export]
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "3D View", style: .plain, target: self, action: #selector(show3D))
        }
    }

    private func setupFooter() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 40))
        let lbl = UILabel()
        lbl.text = "\(totalViewCount) views in hierarchy"
        lbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.25)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
        tableView.tableFooterView = footer
    }

    // MARK: - Tree Building

    private func buildTree() {
        let result = buildNode(view: rootView, depth: 0)
        rootNode = result.node
        totalViewCount = result.count
    }

    private func buildNode(view: UIView, depth: Int) -> (node: TreeNode, count: Int) {
        let node = TreeNode(view: view, depth: depth)
        var count = 1
        for sub in view.subviews {
            let childResult = buildNode(view: sub, depth: depth + 1)
            node.children.append(childResult.node)
            count += childResult.count
        }
        return (node, count)
    }

    private func rebuildDisplayList() {
        displayList = []
        if let root = rootNode { collectVisible(root) }
        tableView.reloadData()
    }

    private func collectVisible(_ node: TreeNode) {
        if !searchText.isEmpty {
            let matches = node.className.lowercased().contains(searchText)
                || (node.view.accessibilityIdentifier?.lowercased().contains(searchText) ?? false)
            let childMatch = node.children.contains { hasMatch($0) }
            guard matches || childMatch else { return }
        }
        displayList.append(node)
        if node.isExpanded {
            for child in node.children { collectVisible(child) }
        }
    }

    private func hasMatch(_ node: TreeNode) -> Bool {
        let matches = node.className.lowercased().contains(searchText)
            || (node.view.accessibilityIdentifier?.lowercased().contains(searchText) ?? false)
        return matches || node.children.contains { hasMatch($0) }
    }

    // MARK: - Actions

    @objc private func show3D() {
        let vc = ViewHierarchy3DVC(rootView: rootView)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        present(nav, animated: true)
    }

    @objc private func exportHierarchy() {
        var lines: [String] = ["View Hierarchy — PhantomSwift", "Date: \(Date())", ""]
        func appendNode(_ node: TreeNode, indent: Int) {
            let prefix = String(repeating: "  ", count: indent) + (indent > 0 ? "└─ " : "")
            var info = "\(prefix)\(node.className)"
            info += " [\(Int(node.view.frame.width))×\(Int(node.view.frame.height))]"
            if node.view.isHidden { info += " (hidden)" }
            if let a11y = node.view.accessibilityIdentifier { info += " #\(a11y)" }
            lines.append(info)
            node.children.forEach { appendNode($0, indent: indent + 1) }
        }
        if let root = rootNode { appendNode(root, indent: 0) }
        lines.append("\nTotal: \(totalViewCount) views")
        let text = lines.joined(separator: "\n")
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }

    @objc private func dismissHierarchy() { dismiss(animated: true) }

    @objc private func collapseAll() {
        setExpanded(rootNode, expanded: false)
        rebuildDisplayList()
    }

    @objc private func expandAll() {
        setExpanded(rootNode, expanded: true)
        rebuildDisplayList()
    }

    private func setExpanded(_ node: TreeNode?, expanded: Bool) {
        guard let node else { return }
        node.isExpanded = expanded
        node.children.forEach { setExpanded($0, expanded: expanded) }
    }

    // MARK: - TableView

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HierarchyNodeCell", for: indexPath) as! HierarchyNodeCell
        let node = displayList[indexPath.row]
        cell.configure(with: node)
        cell.onToggleExpand = { [weak self] in
            node.isExpanded.toggle()
            self?.rebuildDisplayList()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let node = displayList[indexPath.row]
        let detailVC = ViewDetailVC(targetView: node.view)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Search

extension ViewHierarchyVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText.lowercased()
        rebuildDisplayList()
    }
}

// MARK: - HierarchyNodeCell

private final class HierarchyNodeCell: UITableViewCell {
    private let depthBar = UIView()
    private let chevronBtn = UIButton(type: .system)
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let sizeLabel = UILabel()
    private let childBadge = UILabel()
    private let idLabel = UILabel()

    var onToggleExpand: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        selectedBackgroundView = selectedBg

        contentView.addSubview(depthBar)
        depthBar.translatesAutoresizingMaskIntoConstraints = false

        chevronBtn.titleLabel?.font = .systemFont(ofSize: 10, weight: .bold)
        chevronBtn.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        contentView.addSubview(chevronBtn)
        chevronBtn.translatesAutoresizingMaskIntoConstraints = false

        iconLabel.font = .systemFont(ofSize: 14)
        contentView.addSubview(iconLabel)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        sizeLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        contentView.addSubview(sizeLabel)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        childBadge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        childBadge.textColor = UIColor.Phantom.neonAzure
        childBadge.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.12)
        childBadge.textAlignment = .center
        childBadge.layer.cornerRadius = 8
        childBadge.layer.masksToBounds = true
        contentView.addSubview(childBadge)
        childBadge.translatesAutoresizingMaskIntoConstraints = false

        idLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        idLabel.textColor = UIColor.Phantom.vibrantPurple.withAlphaComponent(0.6)
        contentView.addSubview(idLabel)
        idLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            depthBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            depthBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            depthBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            depthBar.widthAnchor.constraint(equalToConstant: 3),

            chevronBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            chevronBtn.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronBtn.widthAnchor.constraint(equalToConstant: 20),

            iconLabel.leadingAnchor.constraint(equalTo: chevronBtn.trailingAnchor, constant: 2),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            sizeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            sizeLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            idLabel.leadingAnchor.constraint(equalTo: sizeLabel.trailingAnchor, constant: 8),
            idLabel.centerYAnchor.constraint(equalTo: sizeLabel.centerYAnchor),

            childBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            childBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            childBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            childBadge.heightAnchor.constraint(equalToConstant: 18),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])
    }

    @objc private func toggleTapped() { onToggleExpand?() }

    func configure(with node: TreeNode) {
        let depth = node.depth
        let indent = CGFloat(depth) * 16 + 12
        chevronBtn.transform = .identity

        // Depth-colored left bar
        let maxHue: CGFloat = 0.75
        let hue = min(CGFloat(depth) / 12.0, 1.0) * maxHue
        depthBar.backgroundColor = UIColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1.0)

        // Indentation via leading constraint update
        for c in contentView.constraints where c.firstAnchor == chevronBtn.leadingAnchor {
            c.constant = indent
        }

        // Chevron
        let hasChildren = !node.children.isEmpty
        if hasChildren {
            if #available(iOS 13.0, *) {
                let icon = node.isExpanded ? "chevron.down" : "chevron.right"
                chevronBtn.setImage(UIImage.phantomSymbol(icon, config: PhantomSymbolConfig(pointSize: 10, weight: .bold)), for: .normal)
                chevronBtn.setTitle(nil, for: .normal)
            } else {
                chevronBtn.setTitle(node.isExpanded ? "v" : ">", for: .normal)
            }
            chevronBtn.tintColor = UIColor.white.withAlphaComponent(0.5)
            chevronBtn.isHidden = false
        } else {
            chevronBtn.isHidden = true
        }

        iconLabel.text = iconForView(node.view)
        nameLabel.text = node.className

        let w = Int(node.view.frame.width)
        let h = Int(node.view.frame.height)
        sizeLabel.text = "\(w) x \(h)"

        if let accId = node.view.accessibilityIdentifier, !accId.isEmpty {
            idLabel.text = "#\(accId)"
            idLabel.isHidden = false
        } else {
            idLabel.isHidden = true
        }

        if hasChildren {
            childBadge.text = " \(node.children.count) "
            childBadge.isHidden = false
        } else {
            childBadge.isHidden = true
        }

        // Dim hidden or zero-alpha views
        contentView.alpha = (node.view.isHidden || node.view.alpha < 0.01) ? 0.35 : 1.0
    }

    private func iconForView(_ view: UIView) -> String {
        if view is UIButton { return "🔘" }
        if view is UILabel { return "📝" }
        if view is UIImageView { return "🖼" }
        if view is UIScrollView { return "📜" }
        if view is UITextField || view is UITextView { return "⌨️" }
        if view is UIStackView { return "📐" }
        if view is UITableView || view is UICollectionView { return "📋" }
        if view is UISwitch { return "🔀" }
        if view is UISlider { return "🎚" }
        if view.subviews.count > 0 { return "📦" }
        return "⬜️"
    }
}
#endif
