#if DEBUG
import UIKit

// MARK: - ObjectRetainGraphVC

/// Shows a Mirror-reflected property tree of a leaked object to help identify
/// what is holding strong references and preventing deallocation.
internal final class ObjectRetainGraphVC: UIViewController {

    // MARK: - Types

    /// A node in the retain graph tree.
    struct RetainNode {
        let depth: Int
        let propertyName: String
        let typeName: String
        let valueSummary: String
        let isObjectRef: Bool   // true if value is a class instance (potential strong ref)
        let isPotentialCycle: Bool // true if the class name looks like it could be a retain cycle source
        var isExpanded: Bool = true
        let children: [RetainNode]
    }

    // MARK: - State

    private let leak: LeakReport
    private var flatNodes: [RetainNode] = []

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let headerCard = UIView()

    // MARK: - Init

    init(leak: LeakReport) {
        self.leak = leak
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Retain Graph"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        buildGraph()
        setupUI()
    }

    // MARK: - Graph Building

    private func buildGraph() {
        // Use Mirror snapshot stored at track time (safe, always available)
        let topNodes = leak.mirroredProperties.map { (label, value) -> RetainNode in
            let isObj = value.hasPrefix("<") && value.contains("@")
            let isPotential = isCycleSuspect(label: label, value: value)
            return RetainNode(
                depth: 0,
                propertyName: label,
                typeName: extractTypeName(from: value),
                valueSummary: value,
                isObjectRef: isObj,
                isPotentialCycle: isPotential,
                isExpanded: true,
                children: []
            )
        }
        flatNodes = topNodes
    }

    private func isCycleSuspect(label: String, value: String) -> Bool {
        // Heuristic: closures (containing "->"), delegates, strong VC refs, parent refs
        let l = label.lowercased()
        if l.contains("delegate") || l.contains("parent") || l.contains("completion") ||
           l.contains("handler") || l.contains("callback") || l.contains("closure") {
            return true
        }
        // Value contains an object reference to a ViewController or View
        if value.lowercased().contains("viewcontroller") || value.lowercased().contains("uiview") {
            return true
        }
        return false
    }

    private func extractTypeName(from value: String) -> String {
        // "<TypeName> @ 0x..." → "TypeName"
        guard value.hasPrefix("<") else { return "value" }
        let inner = value.dropFirst()
        if let end = inner.firstIndex(of: ">") {
            return String(inner[inner.startIndex..<end])
        }
        return "object"
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Header summary card
        buildHeaderCard()

        tableView.backgroundColor    = .clear
        tableView.dataSource         = self
        tableView.delegate           = self
        tableView.register(RetainNodeCell.self, forCellReuseIdentifier: RetainNodeCell.reuseID)
        tableView.rowHeight            = UITableView.automaticDimension
        tableView.estimatedRowHeight   = 56
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView      = UIView()
        tableView.separatorColor       = PhantomTheme.shared.textColor.withAlphaComponent(0.08)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Add nav bar export button
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "doc.on.clipboard"),
                style: .plain,
                target: self,
                action: #selector(copyToClipboard))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Copy", style: .plain,
                target: self, action: #selector(copyToClipboard))
        }
    }

    private func buildHeaderCard() {
        // Will be used as tableView.tableHeaderView
        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.8)

        // Severity badge
        let sevBadge = PaddedTagLabel()
        sevBadge.text             = " \(leak.severity.rawValue.uppercased()) "
        sevBadge.font             = .systemFont(ofSize: 10, weight: .black)
        sevBadge.layer.cornerRadius = 6
        sevBadge.layer.masksToBounds = true
        switch leak.severity {
        case .critical:  sevBadge.backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.2);    sevBadge.textColor = UIColor.Phantom.vibrantRed
        case .confirmed: sevBadge.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.2); sevBadge.textColor = UIColor.Phantom.vibrantOrange
        case .potential: sevBadge.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2);           sevBadge.textColor = UIColor.systemYellow
        }

        let classLbl = UILabel()
        classLbl.text      = leak.className
        classLbl.font      = .systemFont(ofSize: 15, weight: .bold)
        classLbl.textColor = PhantomTheme.shared.textColor

        let addrLbl = UILabel()
        addrLbl.text      = leak.objectAddress
        addrLbl.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        addrLbl.textColor = UIColor.Phantom.neonAzure

        let rcLbl = UILabel()
        rcLbl.text      = "Retain count ≈ \(leak.retainCount)"
        rcLbl.font      = .systemFont(ofSize: 11)
        rcLbl.textColor = UIColor.Phantom.electricIndigo

        let hintLbl = UILabel()
        hintLbl.text          = "⚠️ Orange = likely retain cycle source  •  Red = object ref  •  Tap to copy"
        hintLbl.font          = .systemFont(ofSize: 10)
        hintLbl.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        hintLbl.numberOfLines = 2

        let vstack = UIStackView(arrangedSubviews: [sevBadge, classLbl, addrLbl, rcLbl, hintLbl])
        vstack.axis    = .vertical
        vstack.spacing = 5
        vstack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vstack)

        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            vstack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            vstack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            vstack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        // Size header to fit
        card.translatesAutoresizingMaskIntoConstraints = false
        card.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 160)
        card.layoutIfNeeded()
        let targetSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = card.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        card.frame.size.height = height + 1
        tableView.tableHeaderView = card
    }

    @objc private func copyToClipboard() {
        let lines = flatNodes.map { n in
            "[\(n.typeName)] \(n.propertyName) = \(n.valueSummary)"
        }
        UIPasteboard.general.string = (["=== \(leak.className) Retain Graph ==="] + lines).joined(separator: "\n")
    }
}

// MARK: - UITableViewDataSource + Delegate

extension ObjectRetainGraphVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        flatNodes.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "PROPERTIES  (\(flatNodes.count) captured via Mirror)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RetainNodeCell.reuseID, for: indexPath) as! RetainNodeCell
        cell.configure(with: flatNodes[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font      = .systemFont(ofSize: 10, weight: .black)
        header.textLabel?.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.7)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let node = flatNodes[indexPath.row]
        UIPasteboard.general.string = "\(node.propertyName): \(node.valueSummary)"
    }
}

// MARK: - RetainNodeCell

private final class RetainNodeCell: UITableViewCell {
    static let reuseID = "RetainNodeCell"

    private let typeTag   = PaddedTagLabel()
    private let propLabel = UILabel()
    private let valueLabel = UILabel()
    private let cycleIcon  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .default

        typeTag.font              = .systemFont(ofSize: 9, weight: .bold)
        typeTag.layer.cornerRadius = 4
        typeTag.layer.masksToBounds = true
        typeTag.textAlignment     = .center
        typeTag.translatesAutoresizingMaskIntoConstraints = false

        propLabel.font      = .systemFont(ofSize: 13, weight: .semibold)
        propLabel.textColor = PhantomTheme.shared.textColor
        propLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font          = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor     = PhantomTheme.shared.textColor.withAlphaComponent(0.65)
        valueLabel.numberOfLines = 2
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        cycleIcon.font      = .systemFont(ofSize: 16)
        cycleIcon.textColor = UIColor.Phantom.vibrantOrange
        cycleIcon.text      = "⚠️"
        cycleIcon.isHidden  = true
        cycleIcon.translatesAutoresizingMaskIntoConstraints = false

        [typeTag, propLabel, valueLabel, cycleIcon].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            typeTag.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            typeTag.centerYAnchor.constraint(equalTo: propLabel.centerYAnchor),
            typeTag.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            typeTag.heightAnchor.constraint(equalToConstant: 18),

            propLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            propLabel.leadingAnchor.constraint(equalTo: typeTag.trailingAnchor, constant: 8),
            propLabel.trailingAnchor.constraint(equalTo: cycleIcon.leadingAnchor, constant: -6),

            cycleIcon.centerYAnchor.constraint(equalTo: propLabel.centerYAnchor),
            cycleIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            cycleIcon.widthAnchor.constraint(equalToConstant: 24),

            valueLabel.topAnchor.constraint(equalTo: propLabel.bottomAnchor, constant: 3),
            valueLabel.leadingAnchor.constraint(equalTo: typeTag.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with node: ObjectRetainGraphVC.RetainNode) {
        propLabel.text  = node.propertyName
        valueLabel.text = node.valueSummary
        cycleIcon.isHidden = !node.isPotentialCycle

        let (tagText, tagBg, tagFg): (String, UIColor, UIColor)
        if node.isPotentialCycle {
            tagText = " CYCLE? "
            tagBg   = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.15)
            tagFg   = UIColor.Phantom.vibrantOrange
        } else if node.isObjectRef {
            tagText = " REF "
            tagBg   = UIColor.Phantom.vibrantRed.withAlphaComponent(0.12)
            tagFg   = UIColor.Phantom.vibrantRed
        } else {
            tagText = " VALUE "
            tagBg   = PhantomTheme.shared.textColor.withAlphaComponent(0.08)
            tagFg   = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        }
        typeTag.text            = tagText
        typeTag.backgroundColor = tagBg
        typeTag.textColor       = tagFg
    }
}

// MARK: - PaddedTagLabel

private final class PaddedTagLabel: UILabel {
    private let p = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: p)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + p.left + p.right, height: s.height + p.top + p.bottom)
    }
}

#endif
