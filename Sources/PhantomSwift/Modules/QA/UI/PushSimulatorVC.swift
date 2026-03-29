#if DEBUG
import UIKit
import UserNotifications

// MARK: - PushSimulatorVC

internal final class PushSimulatorVC: UITableViewController {

    // MARK: - State

    private var templates: [PushTemplate] { PhantomPushSimulator.shared.templates }
    private var pendingCount = 0

    // MARK: - Sections
    private enum Section: Int, CaseIterable {
        case pending = 0
        case templates = 1
    }

    // MARK: - Init

    internal init() {
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Push Notifications"
        applyDarkAppearance()
        setupNavBar()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavBarAppearance()
        refreshPending()
    }

    // MARK: - Appearance

    private func applyDarkAppearance() {
        tableView.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset  = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
    }

    private func applyNavBarAppearance() {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.shadowColor     = .clear
            appearance.titleTextAttributes = [
                .foregroundColor: PhantomTheme.shared.textColor,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navigationController?.navigationBar.standardAppearance   = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance    = appearance
            navigationController?.navigationBar.tintColor = PhantomTheme.shared.primaryColor
        } else {
            navigationController?.navigationBar.barTintColor = PhantomTheme.shared.backgroundColor
            navigationController?.navigationBar.tintColor    = PhantomTheme.shared.primaryColor
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: PhantomTheme.shared.textColor]
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        }
    }

    // MARK: - Setup

    private func setupNavBar() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain, target: self, action: #selector(newTemplateTapped)
            )
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain, target: self, action: #selector(closeTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "New", style: .plain, target: self, action: #selector(newTemplateTapped)
            )
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Close", style: .plain, target: self, action: #selector(closeTapped)
            )
        }
    }

    private func setupTableView() {
        tableView.register(PushTemplateCell.self, forCellReuseIdentifier: PushTemplateCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PendingCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func newTemplateTapped() {
        openCompose(template: nil)
    }

    private func openCompose(template: PushTemplate?) {
        let vc = PushComposeVC(template: template) { [weak self] saved in
            PhantomPushSimulator.shared.save(saved)
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func refreshPending() {
        PhantomPushSimulator.shared.getPendingNotifications { [weak self] requests in
            self?.pendingCount = requests.count
            self?.tableView.reloadSections(IndexSet([Section.pending.rawValue]), with: .none)
        }
    }

    private func firePush(_ template: PushTemplate, at indexPath: IndexPath) {
        PhantomPushSimulator.shared.fire(template) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.showToast("Scheduled: \"\(template.name)\"")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshPending() }
            case .permissionDenied:
                self.showPermissionAlert()
            case .error(let msg):
                self.showToast("Error: \(msg)")
            }
        }
    }

    // MARK: - Alerts / Toast

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Notification Permission Required",
            message: "Please allow notifications in Settings to use the Push Simulator.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        label.layoutIfNeeded()
        label.frame.size.width += 24

        UIView.animate(withDuration: 0.3, delay: 1.8, options: .curveEaseIn) {
            label.alpha = 0
        } completion: { _ in label.removeFromSuperview() }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .pending:   return 1
        case .templates: return max(templates.count, 1)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let wrapper = UIView()
        wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
        let label = UILabel()
        switch Section(rawValue: section)! {
        case .pending:   label.text = "PENDING DELIVERY"
        case .templates: label.text = "TEMPLATES"
        }
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
        ])
        return wrapper
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .templates {
            let wrapper = UIView()
            wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
            let label = UILabel()
            label.text          = "Tap to edit  ·  Swipe left to delete  ·  Tap ↗ to fire"
            label.font          = .systemFont(ofSize: 11, weight: .regular)
            label.textColor     = UIColor.white.withAlphaComponent(0.25)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            ])
            return wrapper
        }
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.backgroundColor
        return v
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .templates ? UITableView.automaticDimension : 8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {

        case .pending:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PendingCell", for: indexPath)
            cell.selectionStyle  = .none
            cell.backgroundColor = PhantomTheme.shared.surfaceColor
            if pendingCount == 0 {
                cell.textLabel?.text      = "No pending notifications"
                cell.textLabel?.textColor = UIColor.white.withAlphaComponent(0.25)
            } else {
                cell.textLabel?.text      = "\(pendingCount) notification(s) queued"
                cell.textLabel?.textColor = UIColor.Phantom.vibrantGreen
            }
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)

            let cancelBtn = UIButton(type: .system)
            cancelBtn.setTitle("Cancel All", for: .normal)
            cancelBtn.setTitleColor(UIColor.Phantom.vibrantRed, for: .normal)
            cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            cancelBtn.addTarget(self, action: #selector(cancelAllTapped), for: .touchUpInside)
            cell.accessoryView = pendingCount > 0 ? cancelBtn : nil
            return cell

        case .templates:
            if templates.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "PendingCell", for: indexPath)
                cell.selectionStyle  = .none
                cell.backgroundColor = PhantomTheme.shared.surfaceColor
                cell.textLabel?.text      = "No templates — tap + to create one"
                cell.textLabel?.textColor = UIColor.white.withAlphaComponent(0.25)
                cell.textLabel?.font      = UIFont.systemFont(ofSize: 14, weight: .medium)
                cell.accessoryView = nil
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: PushTemplateCell.reuseID, for: indexPath) as! PushTemplateCell
            cell.configure(with: templates[indexPath.row]) { [weak self] in
                self?.firePush(self!.templates[indexPath.row], at: indexPath)
            }
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .templates, !templates.isEmpty else { return }
        openCompose(template: templates[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .templates && !templates.isEmpty
    }

    override func tableView(_ tableView: UITableView,
                            editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        PhantomPushSimulator.shared.delete(at: IndexSet([indexPath.row]))
        if templates.isEmpty {
            tableView.reloadRows(at: [indexPath], with: .fade)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    @objc private func cancelAllTapped() {
        PhantomPushSimulator.shared.cancelAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshPending()
        }
    }
}

// MARK: - PushTemplateCell

private final class PushTemplateCell: UITableViewCell {

    static let reuseID = "PushTemplateCell"

    private let accentStrip  = UIView()
    private let iconBg       = UIView()
    private let iconView     = UIImageView()
    private let nameLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let badgePill    = UILabel()
    private let fireButton   = UIButton(type: .system)
    private var onFire: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle  = .none

        let highlight = UIView()
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        selectedBackgroundView = highlight

        // ── Left accent strip ────────────────────────────────────────────
        accentStrip.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.8)
        accentStrip.layer.cornerRadius = 2
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentStrip)

        // ── Bell icon in pill background ─────────────────────────────────
        iconBg.backgroundColor  = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 10
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBg)

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            iconView.image = UIImage(systemName: "bell.fill", withConfiguration: cfg)
        }
        iconView.tintColor   = PhantomTheme.shared.primaryColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // ── Name ─────────────────────────────────────────────────────────
        nameLabel.font          = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor     = UIColor.white.withAlphaComponent(0.92)
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // ── Subtitle ─────────────────────────────────────────────────────
        subtitleLabel.font          = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor     = UIColor.white.withAlphaComponent(0.38)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // ── Badge pill ───────────────────────────────────────────────────
        badgePill.font            = UIFont.systemFont(ofSize: 10, weight: .bold)
        badgePill.textColor       = .white
        badgePill.backgroundColor = UIColor.Phantom.vibrantPurple.withAlphaComponent(0.85)
        badgePill.textAlignment   = .center
        badgePill.layer.cornerRadius = 8
        badgePill.clipsToBounds   = true
        badgePill.isHidden        = true
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgePill)

        // ── Fire button ──────────────────────────────────────────────────
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            fireButton.setImage(UIImage(systemName: "paperplane.fill", withConfiguration: cfg), for: .normal)
        } else {
            fireButton.setTitle("Fire", for: .normal)
            fireButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        }
        fireButton.tintColor        = PhantomTheme.shared.primaryColor
        fireButton.backgroundColor  = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        fireButton.layer.cornerRadius = 14
        fireButton.addTarget(self, action: #selector(fireTapped), for: .touchUpInside)
        fireButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fireButton)

        NSLayoutConstraint.activate([
            // Accent strip
            accentStrip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentStrip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            accentStrip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            accentStrip.widthAnchor.constraint(equalToConstant: 3),

            // Icon background pill
            iconBg.leadingAnchor.constraint(equalTo: accentStrip.trailingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 36),
            iconBg.heightAnchor.constraint(equalToConstant: 36),

            // Icon centered in pill
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            // Fire button
            fireButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            fireButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fireButton.widthAnchor.constraint(equalToConstant: 40),
            fireButton.heightAnchor.constraint(equalToConstant: 40),

            // Name
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: fireButton.leadingAnchor, constant: -12),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: fireButton.leadingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            // Badge pill (top-right of icon bg)
            badgePill.topAnchor.constraint(equalTo: iconBg.topAnchor, constant: -4),
            badgePill.trailingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 4),
            badgePill.heightAnchor.constraint(equalToConstant: 16),
            badgePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
        ])
    }

    func configure(with template: PushTemplate, onFire: @escaping () -> Void) {
        self.onFire    = onFire
        nameLabel.text = template.name

        var parts: [String] = []
        if !template.title.isEmpty { parts.append(template.title) }
        if !template.body.isEmpty  { parts.append(template.body) }
        if template.delay > 0      { parts.append("⏱ \(Int(template.delay))s delay") }
        subtitleLabel.text    = parts.joined(separator: "  ·  ")
        subtitleLabel.isHidden = parts.isEmpty

        if let badge = template.badge, badge > 0 {
            badgePill.text    = " \(badge) "
            badgePill.isHidden = false
        } else {
            badgePill.isHidden = true
        }

        // Silent push gets a different icon
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let isSilent = template.sound == "none" && template.title.isEmpty
            iconView.image = UIImage(
                systemName: isSilent ? "antenna.radiowaves.left.and.right" : "bell.fill",
                withConfiguration: cfg
            )
        }
    }

    @objc private func fireTapped() { onFire?() }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) { self.contentView.alpha = highlighted ? 0.6 : 1 }
    }
}

// MARK: - PushComposeVC

internal final class PushComposeVC: UITableViewController {

    // MARK: - State (single source of truth — strings, not UITextField refs)

    private var template: PushTemplate
    private let onSave: (PushTemplate) -> Void

    // Local mutable copies of each field value
    private var nameText:     String
    private var titleText:    String
    private var subtitleText: String
    private var bodyText:     String
    private var badgeText:    String
    private var soundText:    String
    private var delayText:    String
    private var userInfoText: String

    // MARK: - Section / Row layout

    private enum FormSection: Int, CaseIterable {
        case content = 0    // Name, Title, Subtitle, Body
        case options = 1    // Badge, Sound, Delay
        case payload = 2    // JSON
    }

    private struct FieldConfig {
        let label: String
        let placeholder: String
        let keyboard: UIKeyboardType
        let autocap: UITextAutocapitalizationType
        let isSecret: Bool
        init(_ label: String, _ placeholder: String,
             keyboard: UIKeyboardType = .default,
             autocap: UITextAutocapitalizationType = .none,
             isSecret: Bool = false) {
            self.label = label; self.placeholder = placeholder
            self.keyboard = keyboard; self.autocap = autocap; self.isSecret = isSecret
        }
    }

    private let contentFields: [FieldConfig] = [
        FieldConfig("Name",     "My Template",        autocap: .words),
        FieldConfig("Title",    "Notification title",  autocap: .sentences),
        FieldConfig("Subtitle", "Optional subtitle",   autocap: .sentences),
        FieldConfig("Body",     "Notification body",   autocap: .sentences),
    ]
    private let optionFields: [FieldConfig] = [
        FieldConfig("Badge",  "0  =  clear badge",    keyboard: .numberPad),
        FieldConfig("Sound",  "default | none | file.caf"),
        FieldConfig("Delay",  "0 = immediate (s)",    keyboard: .decimalPad),
    ]

    // MARK: - Init

    init(template: PushTemplate?, onSave: @escaping (PushTemplate) -> Void) {
        self.onSave = onSave
        let t = template ?? PushTemplate(
            id: UUID(), name: "", title: "", body: "", subtitle: "",
            categoryIdentifier: "", badge: nil, sound: "default",
            userInfoJSON: "{}", delay: 0
        )
        self.template     = t
        self.nameText     = t.name
        self.titleText    = t.title
        self.subtitleText = t.subtitle
        self.bodyText     = t.body
        self.badgeText    = t.badge.map { "\($0)" } ?? ""
        self.soundText    = t.sound
        self.delayText    = t.delay > 0 ? "\(Int(t.delay))" : ""
        self.userInfoText = t.userInfoJSON

        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = template.name.isEmpty ? "New Template" : "Edit Template"
        setupNavBar()
        setupTableView()
        applyDarkAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavBarAppearance()
    }

    // MARK: - Appearance

    private func applyDarkAppearance() {
        tableView.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.06)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
    }

    private func applyNavBarAppearance() {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.shadowColor     = .clear
            appearance.titleTextAttributes = [
                .foregroundColor: PhantomTheme.shared.textColor,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navigationController?.navigationBar.standardAppearance   = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance    = appearance
            navigationController?.navigationBar.tintColor = PhantomTheme.shared.primaryColor
        } else {
            navigationController?.navigationBar.barTintColor = PhantomTheme.shared.backgroundColor
            navigationController?.navigationBar.tintColor    = PhantomTheme.shared.primaryColor
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: PhantomTheme.shared.textColor]
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        }
    }

    // MARK: - Setup

    private func setupNavBar() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "paperplane.fill"),
                style: .plain, target: self, action: #selector(saveTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Save", style: .done, target: self, action: #selector(saveTapped)
            )
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantPurple
    }

    private func setupTableView() {
        tableView.register(FieldCell.self,  forCellReuseIdentifier: FieldCell.reuseID)
        tableView.register(JSONCell.self,   forCellReuseIdentifier: JSONCell.reuseID)
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight           = UITableView.automaticDimension
        tableView.estimatedRowHeight  = 52
    }

    // MARK: - Save

    @objc private func saveTapped() {
        view.endEditing(true)

        guard !nameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("Template name is required.")
            return
        }

        let rawJSON = userInfoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "{}" : userInfoText
        guard let jsonData = rawJSON.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
            showError("Custom Payload must be valid JSON.")
            return
        }

        template.name         = nameText.trimmingCharacters(in: .whitespaces)
        template.title        = titleText
        template.subtitle     = subtitleText
        template.body         = bodyText
        template.badge        = badgeText.isEmpty ? nil : Int(badgeText)
        template.sound        = soundText.isEmpty ? "default" : soundText
        template.delay        = TimeInterval(delayText) ?? 0
        template.userInfoJSON = rawJSON

        onSave(template)
        navigationController?.popViewController(animated: true)
    }

    private func showError(_ msg: String) {
        let alert = UIAlertController(title: "Invalid", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { FormSection.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch FormSection(rawValue: section) {
        case .content: return contentFields.count   // 4
        case .options: return optionFields.count    // 3
        case .payload: return 1
        case .none:    return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let wrapper = UIView()
        wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
        let label = UILabel()
        switch FormSection(rawValue: section) {
        case .content: label.text = "CONTENT"
        case .options: label.text = "OPTIONS"
        case .payload: label.text = "CUSTOM PAYLOAD (JSON)"
        case .none:    label.text = nil
        }
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
        ])
        return wrapper
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if FormSection(rawValue: section) == .payload {
            let wrapper = UIView()
            wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
            let label = UILabel()
            label.text      = "Must be valid JSON. Merged into UNNotificationContent.userInfo."
            label.font      = .systemFont(ofSize: 11)
            label.textColor = UIColor.white.withAlphaComponent(0.25)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            ])
            return wrapper
        }
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.backgroundColor
        return v
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        FormSection(rawValue: section) == .payload ? UITableView.automaticDimension : 8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch FormSection(rawValue: indexPath.section) {

        case .content:
            let cfg  = contentFields[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: FieldCell.reuseID, for: indexPath) as! FieldCell
            let currentText: String = {
                switch indexPath.row {
                case 0: return nameText
                case 1: return titleText
                case 2: return subtitleText
                case 3: return bodyText
                default: return ""
                }
            }()
            cell.configure(label: cfg.label, text: currentText, placeholder: cfg.placeholder,
                           keyboard: cfg.keyboard, autocap: cfg.autocap)
            cell.onChange = { [weak self] value in
                guard let self else { return }
                switch indexPath.row {
                case 0: self.nameText = value
                case 1: self.titleText = value
                case 2: self.subtitleText = value
                case 3: self.bodyText = value
                default: break
                }
            }
            return cell

        case .options:
            let cfg  = optionFields[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: FieldCell.reuseID, for: indexPath) as! FieldCell
            let currentText: String = {
                switch indexPath.row {
                case 0: return badgeText
                case 1: return soundText
                case 2: return delayText
                default: return ""
                }
            }()
            cell.configure(label: cfg.label, text: currentText, placeholder: cfg.placeholder,
                           keyboard: cfg.keyboard, autocap: cfg.autocap)
            cell.onChange = { [weak self] value in
                guard let self else { return }
                switch indexPath.row {
                case 0: self.badgeText = value
                case 1: self.soundText = value
                case 2: self.delayText = value
                default: break
                }
            }
            return cell

        case .payload:
            let cell = tableView.dequeueReusableCell(withIdentifier: JSONCell.reuseID, for: indexPath) as! JSONCell
            cell.configure(text: userInfoText)
            cell.onChange = { [weak self] value in self?.userInfoText = value }
            return cell

        case .none:
            return UITableViewCell()
        }
    }
}

// MARK: - FieldCell
// Each cell owns its UITextField — no external field embedding to avoid constraint accumulation.

private final class FieldCell: UITableViewCell {
    static let reuseID = "FieldCell"

    var onChange: ((String) -> Void)?

    private let labelView = UILabel()
    private let textField = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle  = .none
        backgroundColor = PhantomTheme.shared.surfaceColor

        labelView.font      = UIFont.systemFont(ofSize: 13, weight: .medium)
        labelView.textColor = UIColor.white.withAlphaComponent(0.4)
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(labelView)

        textField.textColor          = UIColor.white.withAlphaComponent(0.9)
        textField.font               = UIFont.systemFont(ofSize: 15)
        textField.keyboardAppearance = .dark
        textField.clearButtonMode    = .whileEditing
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            labelView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelView.widthAnchor.constraint(equalToConstant: 80),

            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, text: String?, placeholder: String,
                   keyboard: UIKeyboardType = .default,
                   autocap: UITextAutocapitalizationType = .none) {
        labelView.text = label
        textField.text = text
        textField.keyboardType = keyboard
        textField.autocapitalizationType = autocap
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.2)]
        )
    }

    @objc private func textChanged() {
        onChange?(textField.text ?? "")
    }
}

// MARK: - JSONCell

private final class JSONCell: UITableViewCell {
    static let reuseID = "JSONCell"

    var onChange: ((String) -> Void)?

    private let textView = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle  = .none
        backgroundColor = PhantomTheme.shared.surfaceColor

        textView.font = {
            if #available(iOS 13.0, *) {
                return UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            } else {
                return UIFont(name: "Menlo", size: 13) ?? UIFont.systemFont(ofSize: 13)
            }
        }()
        textView.textColor          = UIColor.white.withAlphaComponent(0.85)
        textView.backgroundColor    = .clear
        textView.keyboardAppearance = .dark
        textView.isScrollEnabled    = false
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(text: String) {
        textView.text = text
    }
}

extension JSONCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onChange?(textView.text ?? "")
        // Notify tableView to update cell height
        if let tableView = superview as? UITableView ?? superview?.superview as? UITableView {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }
}
#endif
