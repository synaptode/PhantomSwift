#if DEBUG
import UIKit

/// Developer tools panel: Dark Mode toggle, Dynamic Type slider,
/// Localization switcher, and RTL layout direction toggle.
internal final class DevToolsVC: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private enum Section: Int, CaseIterable {
        case darkMode, dynamicType, localization, rtl

        var title: String {
            switch self {
            case .darkMode: return "INTERFACE STYLE"
            case .dynamicType: return "DYNAMIC TYPE"
            case .localization: return "LOCALIZATION"
            case .rtl: return "LAYOUT DIRECTION"
            }
        }

        var footer: String {
            switch self {
            case .darkMode: return "Overrides the app's user interface style without restarting."
            case .dynamicType: return "Simulates Dynamic Type scale changes for views that observe UIContentSizeCategory."
            case .localization: return "Sets preferred language via AppleLanguages. Requires app restart to fully apply."
            case .rtl: return "Forces right-to-left semantic content layout direction in all views."
            }
        }
    }

    private let contentSizeCategories: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge,
        .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge,
        .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge
    ]

    private let contentSizeCategoryNames = [
        "XS", "S", "M", "L", "XL", "XXL", "XXXL",
        "A1", "A2", "A3", "A4", "A5"
    ]

    private var availableLocalizations: [String] = []
    private var currentLocalizationIndex: Int = 0
    private var isRTLEnabled: Bool = false
    private var dynamicTypeCategoryIndex: Int = 3

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dev Tools"
        setupPhantomAppearance(titleFont: .systemFont(ofSize: 16, weight: .bold))
        setupNavigation()
        setupTableView()
        loadCurrentState()
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .done, target: self, action: #selector(dismissSelf))
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    private func loadCurrentState() {
        // Localizations
        availableLocalizations = Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted()
        let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] ?? []
        let currentLang = langs.first ?? Locale.preferredLanguages.first ?? "en"
        currentLocalizationIndex = availableLocalizations.firstIndex(where: { currentLang.hasPrefix($0) }) ?? 0

        // RTL
        isRTLEnabled = UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft

        // Dynamic Type
        let current = UIApplication.shared.preferredContentSizeCategory
        dynamicTypeCategoryIndex = contentSizeCategories.firstIndex(of: current) ?? 3
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    private func applyDarkMode(_ segmentIndex: Int) {
        guard #available(iOS 13.0, *) else { return }
        let style: UIUserInterfaceStyle
        switch segmentIndex {
        case 0: style = .light
        case 1: style = .dark
        default: style = .unspecified
        }
        UIApplication.shared.windows.forEach { $0.overrideUserInterfaceStyle = style }
    }

    private func applyDynamicType(index: Int) {
        guard index < contentSizeCategories.count else { return }
        let category = contentSizeCategories[index]
        NotificationCenter.default.post(
            name: UIContentSizeCategory.didChangeNotification,
            object: nil,
            userInfo: [UIContentSizeCategory.newValueUserInfoKey: category.rawValue]
        )
        showToast("Dynamic Type: \(contentSizeCategoryNames[safe: index] ?? "L")")
    }

    private func applyLocalization(langCode: String) {
        UserDefaults.standard.set([langCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        showToast("Language → '\(langCode)'. Restart to apply.")
    }

    private func applyRTL(_ enabled: Bool) {
        let semanticAttr: UISemanticContentAttribute = enabled ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = semanticAttr
        // Refresh visible windows
        UIApplication.shared.windows.forEach { window in
            let subs = window.subviews
            subs.forEach { $0.removeFromSuperview() }
            subs.forEach { window.addSubview($0) }
        }
        showToast(enabled ? "RTL Enabled" : "LTR Restored")
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
        toast.numberOfLines = 2
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),
        ])
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }

    // MARK: - Selectors

    @objc private func darkModeChanged(_ seg: UISegmentedControl) {
        applyDarkMode(seg.selectedSegmentIndex)
    }

    @objc private func dynamicTypeChanged(_ slider: UISlider) {
        let index = Int(slider.value.rounded())
        slider.value = Float(index)
        dynamicTypeCategoryIndex = index
        // Update value label in cell
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.dynamicType.rawValue)),
           let label = cell.contentView.viewWithTag(99) as? UILabel {
            label.text = contentSizeCategoryNames[safe: index] ?? "L"
        }
        applyDynamicType(index: index)
    }

    @objc private func rtlToggled(_ sw: UISwitch) {
        isRTLEnabled = sw.isOn
        applyRTL(sw.isOn)
    }
}

// MARK: - UITableViewDataSource

extension DevToolsVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        cell.selectionStyle = .none
        guard let sec = Section(rawValue: indexPath.section) else { return cell }

        switch sec {
        case .darkMode:
            let seg: UISegmentedControl
            if #available(iOS 13.0, *) {
                seg = UISegmentedControl(items: ["Light", "Dark", "System"])
                seg.selectedSegmentIndex = 2
                seg.selectedSegmentTintColor = UIColor.Phantom.neonAzure
            } else {
                seg = UISegmentedControl(items: ["Light", "Dark"])
                seg.selectedSegmentIndex = 0
            }
            seg.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(seg)
            NSLayoutConstraint.activate([
                seg.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                seg.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                seg.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                seg.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                cell.contentView.heightAnchor.constraint(equalToConstant: 56),
            ])
            seg.addTarget(self, action: #selector(darkModeChanged(_:)), for: .valueChanged)

        case .dynamicType:
            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = Float(contentSizeCategories.count - 1)
            slider.value = Float(dynamicTypeCategoryIndex)
            slider.minimumTrackTintColor = UIColor.Phantom.vibrantPurple
            slider.translatesAutoresizingMaskIntoConstraints = false

            let minLabel = UILabel()
            minLabel.text = "XS"
            minLabel.font = .systemFont(ofSize: 9, weight: .bold)
            minLabel.textColor = UIColor.white.withAlphaComponent(0.5)
            minLabel.translatesAutoresizingMaskIntoConstraints = false

            let maxLabel = UILabel()
            maxLabel.text = "A5"
            maxLabel.font = .systemFont(ofSize: 9, weight: .bold)
            maxLabel.textColor = UIColor.white.withAlphaComponent(0.5)
            maxLabel.translatesAutoresizingMaskIntoConstraints = false

            let valueLabel = UILabel()
            valueLabel.text = contentSizeCategoryNames[safe: dynamicTypeCategoryIndex] ?? "L"
            valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .black)
            valueLabel.textColor = UIColor.Phantom.vibrantPurple
            valueLabel.textAlignment = .center
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.tag = 99

            [minLabel, maxLabel, valueLabel, slider].forEach { cell.contentView.addSubview($0) }
            NSLayoutConstraint.activate([
                valueLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
                valueLabel.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                minLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                minLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
                maxLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                maxLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
                slider.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 8),
                slider.leadingAnchor.constraint(equalTo: minLabel.trailingAnchor, constant: 8),
                slider.trailingAnchor.constraint(equalTo: maxLabel.leadingAnchor, constant: -8),
                slider.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
            ])
            slider.addTarget(self, action: #selector(dynamicTypeChanged(_:)), for: .valueChanged)

        case .localization:
            let picker = UIPickerView()
            picker.dataSource = self
            picker.delegate = self
            picker.selectRow(currentLocalizationIndex, inComponent: 0, animated: false)
            picker.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(picker)
            NSLayoutConstraint.activate([
                picker.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                picker.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                picker.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                picker.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                picker.heightAnchor.constraint(equalToConstant: 150),
            ])

        case .rtl:
            let label = UILabel()
            label.text = "Force Right-to-Left"
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false

            let rtlSwitch = UISwitch()
            rtlSwitch.isOn = isRTLEnabled
            rtlSwitch.onTintColor = UIColor.Phantom.vibrantPurple
            rtlSwitch.translatesAutoresizingMaskIntoConstraints = false

            cell.contentView.addSubview(label)
            cell.contentView.addSubview(rtlSwitch)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                rtlSwitch.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                rtlSwitch.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                cell.contentView.heightAnchor.constraint(equalToConstant: 56),
            ])
            rtlSwitch.addTarget(self, action: #selector(rtlToggled(_:)), for: .valueChanged)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section(rawValue: section)?.footer
    }
}

// MARK: - UITableViewDelegate

extension DevToolsVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.4)
        header.textLabel?.font = UIFont.systemFont(ofSize: 10, weight: .black)
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        footer.textLabel?.textColor = UIColor.white.withAlphaComponent(0.3)
        footer.textLabel?.font = UIFont.systemFont(ofSize: 10, weight: .regular)
    }
}

// MARK: - UIPickerViewDataSource / Delegate

extension DevToolsVC: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        availableLocalizations.isEmpty ? 1 : availableLocalizations.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        availableLocalizations.isEmpty ? "en (default)" : availableLocalizations[safe: row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let lang = availableLocalizations[safe: row] else { return }
        currentLocalizationIndex = row
        applyLocalization(langCode: lang)
    }
}

// MARK: - Safe Subscript (private)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
