#if DEBUG
import UIKit

/// Displays all NSLayoutConstraints affecting the target view, grouped by axis.
/// Tap a row to copy its human-readable description. Export all via share sheet.
internal final class ConstraintInspectorVC: UIViewController {

    private let targetView: UIView
    private var sections: [(title: String, rows: [NSLayoutConstraint])] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Constraints"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        applyNavBarStyle()
        collectAndGroup()
        setupTable()
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
                style: .plain, target: self, action: #selector(exportAll))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Export", style: .plain, target: self, action: #selector(exportAll))
        }
    }

    // MARK: - Data

    private func collectAndGroup() {
        let all = collectConstraints()
        var h: [NSLayoutConstraint] = []
        var v: [NSLayoutConstraint] = []
        var d: [NSLayoutConstraint] = []
        var o: [NSLayoutConstraint] = []

        for c in all {
            switch c.firstAttribute {
            case .left, .right, .leading, .trailing,
                 .leftMargin, .rightMargin, .leadingMargin, .trailingMargin,
                 .centerX, .centerXWithinMargins:
                h.append(c)
            case .top, .bottom, .topMargin, .bottomMargin,
                 .firstBaseline, .lastBaseline, .centerY, .centerYWithinMargins:
                v.append(c)
            case .width, .height:
                d.append(c)
            default:
                o.append(c)
            }
        }

        sections = []
        if !h.isEmpty { sections.append(("↔  Horizontal  (\(h.count))", h)) }
        if !v.isEmpty { sections.append(("↕  Vertical  (\(v.count))", v)) }
        if !d.isEmpty { sections.append(("⬜  Dimension  (\(d.count))", d)) }
        if !o.isEmpty { sections.append(("•  Other  (\(o.count))", o)) }
    }

    private func collectConstraints() -> [NSLayoutConstraint] {
        var result = Array(targetView.constraints)
        if let sv = targetView.superview {
            let related = sv.constraints.filter {
                ($0.firstItem as? UIView) === targetView || ($0.secondItem as? UIView) === targetView
            }
            result.append(contentsOf: related)
        }
        var seen = Set<ObjectIdentifier>()
        return result.filter { seen.insert(ObjectIdentifier($0)).inserted }
    }

    // MARK: - Table

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ConstraintRowCell.self, forCellReuseIdentifier: "ConstraintRowCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if sections.isEmpty {
            let lbl = UILabel()
            lbl.text = "No constraints found\nfor this view."
            lbl.numberOfLines = 0
            lbl.textAlignment = .center
            lbl.textColor = UIColor.white.withAlphaComponent(0.3)
            lbl.font = .systemFont(ofSize: 14, weight: .medium)
            tableView.backgroundView = lbl
        }
    }

    // MARK: - Actions

    @objc private func handleDone() { dismiss(animated: true) }

    @objc private func exportAll() {
        let all = sections.flatMap { $0.rows }
        var lines = [
            "Constraints — \(type(of: targetView))",
            "Total: \(all.count) constraints",
            "=========================="
        ]
        for sec in sections {
            lines.append("\n\(sec.title)")
            for c in sec.rows { lines.append("  " + humanDescription(c)) }
        }
        let vc = UIActivityViewController(
            activityItems: [lines.joined(separator: "\n")],
            applicationActivities: nil)
        present(vc, animated: true)
    }

    // MARK: - Helpers

    func humanDescription(_ c: NSLayoutConstraint) -> String {
        func entityName(_ item: AnyObject?) -> String {
            guard let v = item as? UIView else {
                return item.map { "\(type(of: $0))" } ?? "nil"
            }
            if v === targetView          { return "view" }
            if v === targetView.superview { return "superview" }
            return String(describing: type(of: v))
        }

        let lhs    = "\(entityName(c.firstItem)).\(attrName(c.firstAttribute))"
        let rhs    = c.secondAttribute != .notAnAttribute
            ? " \(relSym(c.relation)) \(entityName(c.secondItem)).\(attrName(c.secondAttribute))"
            : ""
        let k      = c.constant   != 0   ? " + \(c.constant)"   : ""
        let m      = c.multiplier != 1.0 ? " × \(c.multiplier)" : ""
        let inactive = c.isActive ? "" : " [INACTIVE]"
        return "\(lhs)\(rhs)\(k)\(m) @\(Int(c.priority.rawValue))\(inactive)"
    }

    private func attrName(_ a: NSLayoutConstraint.Attribute) -> String {
        switch a {
        case .left:                  return "left"
        case .right:                 return "right"
        case .top:                   return "top"
        case .bottom:                return "bottom"
        case .leading:               return "leading"
        case .trailing:              return "trailing"
        case .width:                 return "width"
        case .height:                return "height"
        case .centerX:               return "centerX"
        case .centerY:               return "centerY"
        case .firstBaseline:         return "firstBaseline"
        case .lastBaseline:          return "lastBaseline"
        case .leftMargin:            return "leftMargin"
        case .rightMargin:           return "rightMargin"
        case .topMargin:             return "topMargin"
        case .bottomMargin:          return "bottomMargin"
        case .leadingMargin:         return "leadingMargin"
        case .trailingMargin:        return "trailingMargin"
        case .centerXWithinMargins:  return "centerX(margin)"
        case .centerYWithinMargins:  return "centerY(margin)"
        case .notAnAttribute:        return "-"
        @unknown default:            return "?"
        }
    }

    private func relSym(_ r: NSLayoutConstraint.Relation) -> String {
        switch r {
        case .lessThanOrEqual:    return "≤"
        case .equal:              return "="
        case .greaterThanOrEqual: return "≥"
        @unknown default:         return "?"
        }
    }

    private func priorityColor(for c: NSLayoutConstraint) -> UIColor {
        guard c.isActive else { return UIColor.white.withAlphaComponent(0.15) }
        let p = c.priority.rawValue
        if p >= 1000 { return UIColor.Phantom.neonAzure }
        if p >= 750  { return UIColor.Phantom.vibrantGreen }
        if p >= 500  { return UIColor.Phantom.vibrantOrange }
        return UIColor.Phantom.vibrantRed
    }

    func showCopyToast() {
        let toast = UILabel()
        toast.text = "  ✓ Copied to Clipboard  "
        toast.font = .systemFont(ofSize: 12, weight: .bold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.95)
        toast.layer.cornerRadius = 14
        toast.layer.masksToBounds = true
        toast.textAlignment = .center
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 36)
        ])
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}

// MARK: - UITableViewDataSource, Delegate

extension ConstraintInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.6)
        let label = UILabel()
        label.text = sections[section].title
        label.font = .systemFont(ofSize: 10, weight: .black)
        label.textColor = UIColor.Phantom.neonAzure
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 32),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 32 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ConstraintRowCell",
            for: indexPath) as! ConstraintRowCell
        let c = sections[indexPath.section].rows[indexPath.row]
        cell.configure(
            description: humanDescription(c),
            meta: "const: \(String(format: "%.1f", c.constant))  ×\(String(format: "%.2f", c.multiplier))  @\(Int(c.priority.rawValue))",
            priorityColor: priorityColor(for: c),
            isActive: c.isActive)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 72 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = sections[indexPath.section].rows[indexPath.row]
        UIPasteboard.general.string = humanDescription(c)
        showCopyToast()
    }
}

// MARK: - ConstraintRowCell

private final class ConstraintRowCell: UITableViewCell {

    private let priorityBar = UIView()
    private let descLabel   = UILabel()
    private let metaLabel   = UILabel()
    private let badge       = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        priorityBar.layer.cornerRadius = 2
        priorityBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priorityBar)

        descLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        descLabel.textColor = .white
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descLabel)

        metaLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        badge.font = .systemFont(ofSize: 9, weight: .black)
        badge.layer.cornerRadius = 6
        badge.layer.masksToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badge)

        NSLayoutConstraint.activate([
            priorityBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            priorityBar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityBar.widthAnchor.constraint(equalToConstant: 4),
            priorityBar.heightAnchor.constraint(equalToConstant: 44),

            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            badge.centerYAnchor.constraint(equalTo: desc_centerY),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            badge.heightAnchor.constraint(equalToConstant: 20),

            descLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            descLabel.leadingAnchor.constraint(equalTo: priorityBar.trailingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -8),

            metaLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: descLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private var desc_centerY: NSLayoutYAxisAnchor { descLabel.centerYAnchor }

    required init?(coder: NSCoder) { fatalError() }

    func configure(description: String, meta: String, priorityColor: UIColor, isActive: Bool) {
        priorityBar.backgroundColor = priorityColor
        descLabel.text = description
        metaLabel.text = meta
        if isActive {
            badge.text = "  ACTIVE  "
            badge.textColor = UIColor.Phantom.vibrantGreen
            badge.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.12)
        } else {
            badge.text = "  INACTIVE  "
            badge.textColor = UIColor.white.withAlphaComponent(0.3)
            badge.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        }
    }
}

#endif
