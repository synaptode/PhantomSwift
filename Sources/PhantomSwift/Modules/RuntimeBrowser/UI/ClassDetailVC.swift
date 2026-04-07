#if DEBUG
import UIKit

/// Displays methods, properties, ivars, and protocols for an Objective-C class.
internal final class ClassDetailVC: UIViewController {

    // MARK: - State

    private let inspectedClassName: String
    private var classInfo: PhantomClassInfo?
    private var activeSegment: Int = 0

    // MARK: - Section model

    private struct Section {
        let title: String
        let rows: [String]
    }
    private var sections: [Section] = []

    // MARK: - UI

    private let headerCard  = UIView()
    private let classLabel  = UILabel()
    private let superLabel  = UILabel()
    private let sizeLabel   = UILabel()
    private let protoBadges = UIStackView()

    private let segmentedControl = UISegmentedControl(items: ["Methods", "Properties", "Ivars"])
    private let tableView  = UITableView(frame: .zero, style: .grouped)
    private let loadingIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        } else {
            return UIActivityIndicatorView(style: .gray)
        }
    }()
    private let emptyView = PhantomEmptyStateView(
        emoji: "📭",
        title: "None Found",
        message: "This class has no items in this category."
    )

    // MARK: - Init

    init(className: String) {
        self.inspectedClassName = className
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helpers

    /// Extracts the simple class name from a potentially mangled Swift name.
    /// "AAAFoundationSwift.DependencyRegistry" → "DependencyRegistry"
    private var simpleClassName: String {
        if let dot = inspectedClassName.lastIndex(of: ".") {
            let after = inspectedClassName.index(after: dot)
            let simple = String(inspectedClassName[after...])
            return simple.isEmpty ? inspectedClassName : simple
        }
        return inspectedClassName
    }

    /// Module part of the mangled name, or nil if not mangled.
    private var moduleName: String? {
        guard let dot = inspectedClassName.lastIndex(of: ".") else { return nil }
        let prefix = String(inspectedClassName[..<dot])
        return prefix.isEmpty ? nil : prefix
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupNavigationBar()
        setupHeader()
        setupSegment()
        setupTable()
        setupLoading()
        loadInfoAsync()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phantom_applyNavBarAppearance()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // Use only the simple name in the nav bar — full name shown in header card
        title = simpleClassName
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "doc.on.doc"),
                style: .plain,
                target: self,
                action: #selector(copyClassName)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Copy",
                style: .plain,
                target: self,
                action: #selector(copyClassName)
            )
        }
        phantom_applyNavBarAppearance()
    }

    @objc private func copyClassName() {
        UIPasteboard.general.string = inspectedClassName
        let alert = UIAlertController(title: "Copied", message: "\(inspectedClassName) copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupHeader() {
        headerCard.backgroundColor = PhantomTheme.shared.surfaceColor
        headerCard.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { headerCard.layer.cornerCurve = .continuous }
        headerCard.layer.borderWidth = 1
        headerCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerCard)

        // Module tag (e.g. "AAAFoundationSwift") — shown only when mangled
        let moduleTag = UILabel()
        moduleTag.text      = moduleName.map { "in \($0)" }
        moduleTag.font      = .systemFont(ofSize: 10, weight: .medium)
        moduleTag.textColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.8)
        moduleTag.isHidden  = moduleName == nil
        moduleTag.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(moduleTag)

        classLabel.text      = simpleClassName
        classLabel.font      = UIFont.phantomMonospaced(size: 16, weight: .bold)
        classLabel.textColor = PhantomTheme.shared.textColor
        classLabel.numberOfLines = 2
        classLabel.translatesAutoresizingMaskIntoConstraints = false

        superLabel.font      = UIFont.systemFont(ofSize: 12, weight: .regular)
        superLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.45)
        superLabel.translatesAutoresizingMaskIntoConstraints = false

        sizeLabel.font      = UIFont.systemFont(ofSize: 11, weight: .semibold)
        sizeLabel.textColor = PhantomTheme.shared.primaryColor
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        protoBadges.axis    = .horizontal
        protoBadges.spacing = 5
        protoBadges.translatesAutoresizingMaskIntoConstraints = false

        [classLabel, superLabel, sizeLabel, protoBadges].forEach { headerCard.addSubview($0) }

        let topPad: CGFloat = moduleName != nil ? 30 : 14
        NSLayoutConstraint.activate([
            headerCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            headerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            moduleTag.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 10),
            moduleTag.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 14),

            classLabel.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: topPad),
            classLabel.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 14),
            classLabel.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -14),

            superLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 5),
            superLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            superLabel.trailingAnchor.constraint(equalTo: classLabel.trailingAnchor),

            sizeLabel.topAnchor.constraint(equalTo: superLabel.bottomAnchor, constant: 6),
            sizeLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),

            protoBadges.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 8),
            protoBadges.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            protoBadges.trailingAnchor.constraint(lessThanOrEqualTo: headerCard.trailingAnchor, constant: -14),
            protoBadges.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -14),
        ])
    }

    private func setupSegment() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.applyPhantomStyle()
        if #available(iOS 13.0, *) {
            segmentedControl.backgroundColor = PhantomTheme.shared.surfaceColor
        } else {
            segmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        }
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
        ])
    }

    private func setupTable() {
        // Use .plain to fully own background — .grouped causes system cell bg (white in light mode)
        // tableView is declared as .grouped; re-init as plain for full dark control
        tableView.backgroundColor   = PhantomTheme.shared.backgroundColor
        tableView.separatorColor    = UIColor.white.withAlphaComponent(0.07)
        tableView.separatorInset    = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.tableFooterView   = UIView()
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(RuntimeDetailCell.self, forCellReuseIdentifier: RuntimeDetailCell.reuseID)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
        ])
    }

    private func setupLoading() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = PhantomTheme.shared.primaryColor
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
        ])
    }

    // MARK: - Data Loading

    private func loadInfoAsync() {
        loadingIndicator.startAnimating()
        tableView.isHidden = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let info = PhantomRuntimeInspector.shared.classInfo(for: self.inspectedClassName)
            DispatchQueue.main.async {
                self.classInfo = info
                self.loadingIndicator.stopAnimating()
                self.tableView.isHidden = false
                self.updateHeader()
                self.reloadCurrentSegment()
            }
        }
    }

    private func updateHeader() {
        guard let info = classInfo else { return }
        if let superName = info.superclassName {
            superLabel.text = "▸ \(superName)"
        } else {
            superLabel.text = "Root class"
        }
        sizeLabel.text = "Instance size: \(info.instanceSize) bytes"

        // Protocol badges
        protoBadges.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for proto in info.protocols.prefix(5) {
            let badge = makeBadge(proto)
            protoBadges.addArrangedSubview(badge)
        }
        if info.protocols.count > 5 {
            let more = makeBadge("+\(info.protocols.count - 5) more")
            protoBadges.addArrangedSubview(more)
        }
    }

    private func makeBadge(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 9, weight: .bold)
        l.textColor = PhantomTheme.shared.primaryColor
        l.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.15)
        l.layer.cornerRadius = 5
        l.layer.masksToBounds = true
        l.textAlignment = .center
        l.setContentHuggingPriority(.required, for: .horizontal)
        // Padding via inset — use a container view for left/right insets
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            l.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            l.heightAnchor.constraint(equalToConstant: 18),
        ])
        return l
    }

    // MARK: - Segment

    @objc private func segmentChanged() {
        activeSegment = segmentedControl.selectedSegmentIndex
        reloadCurrentSegment()
    }

    private func reloadCurrentSegment() {
        guard let info = classInfo else { return }
        switch activeSegment {
        case 0: buildMethodSections(info)
        case 1: buildPropertySections(info)
        case 2: buildIvarSections(info)
        default: break
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func buildMethodSections(_ info: PhantomClassInfo) {
        let instance = info.methods.filter { !$0.isClassMethod }
        let classMethods = info.methods.filter { $0.isClassMethod }
        sections = []
        if !instance.isEmpty  { sections.append(Section(title: "Instance Methods (\(instance.count))", rows: instance.map { $0.displaySignature })) }
        if !classMethods.isEmpty { sections.append(Section(title: "Class Methods (\(classMethods.count))", rows: classMethods.map { $0.displaySignature })) }
    }

    private func buildPropertySections(_ info: PhantomClassInfo) {
        let readonly  = info.properties.filter { $0.isReadOnly }
        let readwrite = info.properties.filter { !$0.isReadOnly }
        sections = []
        if !readwrite.isEmpty { sections.append(Section(title: "Read-Write (\(readwrite.count))", rows: readwrite.map { "@property \($0.type) \($0.name)" })) }
        if !readonly.isEmpty  { sections.append(Section(title: "Read-Only (\(readonly.count))",   rows: readonly.map  { "@property(readonly) \($0.type) \($0.name)" })) }
    }

    private func buildIvarSections(_ info: PhantomClassInfo) {
        sections = info.ivars.isEmpty ? [] : [
            Section(title: "Instance Variables (\(info.ivars.count))",
                    rows: info.ivars.map { "\($0.type) \($0.name)  @\($0.offset)" })
        ]
    }

    private func updateEmptyState() {
        let empty = sections.isEmpty || sections.allSatisfy { $0.rows.isEmpty }
        emptyView.isHidden = !empty
        tableView.isHidden = empty
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ClassDetailVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil // handled by viewForHeaderInSection
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = PhantomTheme.shared.backgroundColor

        let label = UILabel()
        label.text      = sections[section].title
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.35)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.backgroundColor
        return v
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 12 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: RuntimeDetailCell.reuseID, for: indexPath) as? RuntimeDetailCell
        else { return UITableViewCell() }
        let text = sections[indexPath.section].rows[indexPath.row]
        // Accent color: Methods = azure, Properties = green, Ivars = orange
        let accent: UIColor
        switch activeSegment {
        case 0:  accent = UIColor.Phantom.neonAzure
        case 1:  accent = UIColor.Phantom.vibrantGreen
        default: accent = UIColor.Phantom.vibrantOrange
        }
        cell.configure(text: text, accentColor: accent)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let text = sections[indexPath.section].rows[indexPath.row]
        UIPasteboard.general.string = text
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - RuntimeDetailCell

private final class RuntimeDetailCell: UITableViewCell {
    static let reuseID = "RuntimeDetailCell"

    private let accentStrip = UIView()
    private let tokenLabel  = UILabel()  // return type / keyword (leading, colored)
    private let textLbl     = UILabel()  // main signature text

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Explicit dark surface — blocks grouped-table system background
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle  = .none

        let highlight = UIView()
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        selectedBackgroundView = highlight

        // Left accent strip (colored per category, set in configure)
        accentStrip.layer.cornerRadius = 2
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentStrip)

        // Small leading token (e.g. "- " or "+ " for methods, "@property" for props)
        tokenLabel.font          = UIFont.phantomMonospaced(size: 10, weight: .bold)
        tokenLabel.textAlignment = .left
        tokenLabel.setContentHuggingPriority(.required, for: .horizontal)
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tokenLabel)

        textLbl.font          = UIFont.phantomMonospaced(size: 11, weight: .regular)
        textLbl.textColor     = UIColor.white.withAlphaComponent(0.82)
        textLbl.numberOfLines = 0
        textLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textLbl)

        NSLayoutConstraint.activate([
            accentStrip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentStrip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            accentStrip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            accentStrip.widthAnchor.constraint(equalToConstant: 3),

            tokenLabel.leadingAnchor.constraint(equalTo: accentStrip.trailingAnchor, constant: 12),
            tokenLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            textLbl.leadingAnchor.constraint(equalTo: tokenLabel.trailingAnchor, constant: 4),
            textLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textLbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    /// accentColor drives the left strip + token color.
    func configure(text: String, accentColor: UIColor) {
        accentStrip.backgroundColor = accentColor.withAlphaComponent(0.7)
        tokenLabel.textColor        = accentColor

        // Extract leading token: "-", "+", "@property", "@property(readonly)"
        if text.hasPrefix("-") || text.hasPrefix("+") {
            tokenLabel.text = String(text.prefix(1))
            textLbl.text    = String(text.dropFirst(2))
        } else if text.hasPrefix("@property(readonly)") {
            tokenLabel.text = "@readonly"
            textLbl.text    = String(text.dropFirst("@property(readonly) ".count))
        } else if text.hasPrefix("@property") {
            tokenLabel.text = "@prop"
            textLbl.text    = String(text.dropFirst("@property ".count))
        } else {
            tokenLabel.text = "→"
            textLbl.text    = text
        }
    }
    
    func configure(text: String) {
        configure(text: text, accentColor: UIColor.Phantom.neonAzure)
    }
}
#endif
