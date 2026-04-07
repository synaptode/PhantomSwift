#if DEBUG
import UIKit

/// Scans a view hierarchy for accessibility issues:
/// touch target size, color contrast ratio, and missing accessibility labels.
internal final class AccessibilityAuditVC: UIViewController {

    private let rootView: UIView
    private var issues: [AuditIssue] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - Data Model

    internal struct AuditIssue {
        let severity: Severity
        let viewDescription: String
        let title: String
        let detail: String
        let wcagRef: String?

        enum Severity: String {
            case critical = "CRITICAL"
            case warning  = "WARNING"
            case info     = "INFO"

            var color: UIColor {
                switch self {
                case .critical: return UIColor.Phantom.vibrantRed
                case .warning:  return UIColor.Phantom.vibrantOrange
                case .info:     return UIColor.Phantom.neonAzure
                }
            }
        }
    }

    // MARK: - Init

    internal init(rootView: UIView) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Accessibility Audit"
        setupPhantomAppearance()
        setupNavigation()
        performAudit()
        setupTableView()
    }

    private func setupNavigation() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain, target: self, action: #selector(exportReport))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Export", style: .plain, target: self, action: #selector(exportReport))
        }
    }

    // MARK: - Audit

    private func performAudit() {
        issues.removeAll()
        scanView(rootView)
    }

    private func scanView(_ view: UIView) {
        // Skip Phantom internal views
        let className = String(describing: type(of: view))
        if className.hasPrefix("Phantom") || className.hasPrefix("_") { return }

        let isInteractive = view is UIButton || view is UIControl || view.isUserInteractionEnabled

        // 1. Touch target size
        if view is UIButton || view is UIControl {
            if view.frame.width < 44 || view.frame.height < 44 {
                issues.append(AuditIssue(
                    severity: .warning,
                    viewDescription: className,
                    title: "Small Touch Target",
                    detail: "\(className): \(Int(view.frame.width))×\(Int(view.frame.height))pt — Apple HIG requires ≥44×44pt minimum.",
                    wcagRef: "WCAG 2.5.5 (AAA)"
                ))
            }
        }

        // 2. Missing accessibility label on interactive elements
        if (view is UIButton || view is UIControl) && view.accessibilityLabel == nil && !view.isHidden {
            issues.append(AuditIssue(
                severity: .critical,
                viewDescription: className,
                title: "Missing Accessibility Label",
                detail: "\(className) has no accessibilityLabel. VoiceOver users cannot identify this element.",
                wcagRef: "WCAG 1.1.1 (A)"
            ))
        }

        // 3. Color contrast for UILabel
        if let label = view as? UILabel, let textColor = label.textColor {
            let bgColor = resolveBackground(for: label)
            let ratio = contrastRatio(textColor, bgColor)
            let isBold = label.font.fontDescriptor.symbolicTraits.contains(.traitBold)
            let isLargeText = label.font.pointSize >= 18 || (isBold && label.font.pointSize >= 14)

            let aaMin: CGFloat  = isLargeText ? 3.0 : 4.5
            let aaaMin: CGFloat = isLargeText ? 4.5 : 7.0

            if ratio < aaMin {
                issues.append(AuditIssue(
                    severity: .critical,
                    viewDescription: className,
                    title: "Insufficient Color Contrast",
                    detail: "\(className): contrast \(String(format: "%.2f", ratio)):1 — fails AA (requires \(String(format: "%.1f", aaMin)):1).",
                    wcagRef: "WCAG 1.4.3 (AA)"
                ))
            } else if ratio < aaaMin {
                issues.append(AuditIssue(
                    severity: .warning,
                    viewDescription: className,
                    title: "Low Contrast (Fails AAA)",
                    detail: "\(className): contrast \(String(format: "%.2f", ratio)):1 — passes AA but fails AAA (\(String(format: "%.1f", aaaMin)):1).",
                    wcagRef: "WCAG 1.4.6 (AAA)"
                ))
            }
        }

        // 4. Hidden interactive element
        if (view is UIButton || view is UIControl) && view.isHidden {
            issues.append(AuditIssue(
                severity: .info,
                viewDescription: className,
                title: "Hidden Interactive Element",
                detail: "\(className) is currently hidden. Verify this is intentional.",
                wcagRef: nil
            ))
        }

        // 5. Low alpha on interactive element
        if (view is UIButton || view is UIControl) && view.alpha < 0.3 && !view.isHidden {
            issues.append(AuditIssue(
                severity: .warning,
                viewDescription: className,
                title: "Near-Invisible Interactive Element",
                detail: "\(className) alpha is \(String(format: "%.2f", view.alpha)) — may be undetectable.",
                wcagRef: "WCAG 1.4.3 (AA)"
            ))
        }

        view.subviews.forEach { scanView($0) }
    }

    // MARK: - Contrast Math (WCAG relative luminance)

    private func resolveBackground(for label: UILabel) -> UIColor {
        var view: UIView? = label
        while let v = view {
            if let bg = v.backgroundColor, bg != .clear {
                var alpha: CGFloat = 0
                bg.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                if alpha > 0.5 { return bg }
            }
            view = v.superview
        }
        return .white // Assume light background as safe fallback
    }

    private func contrastRatio(_ c1: UIColor, _ c2: UIColor) -> CGFloat {
        let l1 = relativeLuminance(c1)
        let l2 = relativeLuminance(c2)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    // MARK: - Table Setup

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.dataSource = self
        tableView.register(AuditIssueCell.self, forCellReuseIdentifier: AuditIssueCell.reuseID)
        tableView.tableHeaderView = buildSummaryHeader()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildSummaryHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 110))

        var critCount = 0, warnCount = 0, infoCount = 0
        for issue in issues {
            switch issue.severity {
            case .critical: critCount += 1
            case .warning:  warnCount += 1
            case .info:     infoCount += 1
            }
        }

        let titleLabel = UILabel()
        if issues.isEmpty {
            titleLabel.text = "✅ No accessibility issues found"
            titleLabel.textColor = UIColor.Phantom.vibrantGreen
        } else {
            titleLabel.text = "\(issues.count) issue\(issues.count == 1 ? "" : "s") detected"
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        }
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let critPill = makePill(count: critCount, label: "CRITICAL", color: UIColor.Phantom.vibrantRed)
        let warnPill = makePill(count: warnCount, label: "WARNING",  color: UIColor.Phantom.vibrantOrange)
        let infoPill = makePill(count: infoCount, label: "INFO",     color: UIColor.Phantom.neonAzure)

        let stack = UIStackView(arrangedSubviews: [critPill, warnPill, infoPill])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(titleLabel)
        header.addSubview(stack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 14),
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -14),
        ])
        return header
    }

    private func makePill(count: Int, label: String, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = color.withAlphaComponent(0.3).cgColor

        let cntLabel = UILabel()
        cntLabel.text = "\(count)"
        cntLabel.font = .systemFont(ofSize: 22, weight: .black)
        cntLabel.textColor = count > 0 ? color : UIColor.white.withAlphaComponent(0.3)
        cntLabel.textAlignment = .center
        cntLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = .systemFont(ofSize: 7, weight: .black)
        nameLabel.textColor = color.withAlphaComponent(0.7)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(cntLabel)
        container.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            cntLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            cntLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: cntLabel.bottomAnchor, constant: 2),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        return container
    }

    // MARK: - Export

    @objc private func exportReport() {
        guard !issues.isEmpty else { return }
        var report = "PhantomSwift — Accessibility Audit Report\n"
        report += "Date: \(Date())\n"
        report += "Issues: \(issues.count)\n\n"
        issues.forEach { issue in
            report += "[\(issue.severity.rawValue)] \(issue.title)\n"
            report += "  \(issue.detail)\n"
            if let wcag = issue.wcagRef { report += "  \(wcag)\n" }
            report += "\n"
        }
        let vc = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension AccessibilityAuditVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { issues.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AuditIssueCell.reuseID, for: indexPath) as! AuditIssueCell
        cell.configure(with: issues[indexPath.row])
        return cell
    }
}

// MARK: - AuditIssueCell

private final class AuditIssueCell: UITableViewCell {
    static let reuseID = "AuditIssueCell"

    private let severityBadge = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let wcagLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        severityBadge.font = .systemFont(ofSize: 8, weight: .black)
        severityBadge.layer.cornerRadius = 6
        severityBadge.layer.masksToBounds = true
        severityBadge.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        detailLabel.numberOfLines = 4
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        wcagLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        wcagLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        wcagLabel.translatesAutoresizingMaskIntoConstraints = false

        [severityBadge, titleLabel, detailLabel, wcagLabel].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            severityBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            severityBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: severityBadge.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            wcagLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 6),
            wcagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            wcagLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with issue: AccessibilityAuditVC.AuditIssue) {
        let color = issue.severity.color
        severityBadge.text = "  \(issue.severity.rawValue)  "
        severityBadge.textColor = color
        severityBadge.backgroundColor = color.withAlphaComponent(0.15)
        titleLabel.text = issue.title
        detailLabel.text = issue.detail
        wcagLabel.text = issue.wcagRef
        wcagLabel.isHidden = issue.wcagRef == nil
    }
}
#endif
