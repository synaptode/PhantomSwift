#if DEBUG
import UIKit

// MARK: - EnvironmentOverrideVC

/// Runtime environment override panel.
/// Allows toggling dark/light mode, screen brightness, RTL direction,
/// dynamic type size (iOS 17+), and viewing system accessibility/thermal state.
internal final class EnvironmentOverrideVC: UITableViewController {

    private var sections: [EnvSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Environment Override"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.backgroundColor = PhantomTheme.shared.backgroundColor
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)

        if #available(iOS 13.0, *) {
            let app = UINavigationBarAppearance()
            app.configureWithOpaqueBackground()
            app.backgroundColor = PhantomTheme.shared.backgroundColor
            app.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = app
            navigationController?.navigationBar.scrollEdgeAppearance = app
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .done, target: self, action: #selector(close))
        let resetBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            resetBtn = UIBarButtonItem(
                image: UIImage(systemName: "arrow.counterclockwise"),
                style: .plain, target: self, action: #selector(resetAll))
        } else {
            resetBtn = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetAll))
        }
        navigationItem.rightBarButtonItem = resetBtn

        tableView.register(EnvToggleCell.self, forCellReuseIdentifier: "EnvToggleCell")
        tableView.register(EnvSliderCell.self, forCellReuseIdentifier: "EnvSliderCell")
        tableView.register(EnvSegmentCell.self, forCellReuseIdentifier: "EnvSegmentCell")
        tableView.register(EnvStepperCell.self, forCellReuseIdentifier: "EnvStepperCell")
        tableView.register(EnvInfoCell.self, forCellReuseIdentifier: "EnvInfoCell")

        buildSections()
    }

    // MARK: - Section Building

    private func buildSections() {
        sections = [
            buildInterfaceSection(),
            buildLayoutSection(),
            buildDynamicTypeSection(),
            buildAccessibilitySection(),
            buildSystemSection(),
        ]
        tableView.reloadData()
    }

    private func buildInterfaceSection() -> EnvSection {
        var rows: [EnvRow] = []

        // Appearance override (iOS 13+)
        if #available(iOS 13.0, *) {
            let current = PhantomPresentationResolver.activeHostWindow()?.overrideUserInterfaceStyle ?? .unspecified
            let idx = [UIUserInterfaceStyle.unspecified, .light, .dark].firstIndex(of: current) ?? 0
            rows.append(EnvRow(
                type: .segment(options: ["System", "Light", "Dark"], selected: idx),
                title: "Appearance",
                icon: "sun.max.fill",
                onSegmentChange: { newIdx in
                    let style: UIUserInterfaceStyle = [.unspecified, .light, .dark][newIdx]
                    PhantomPresentationResolver.hostWindows().forEach { $0.overrideUserInterfaceStyle = style }
                }
            ))
        }

        // Screen Brightness
        rows.append(EnvRow(
            type: .slider(value: Float(UIScreen.main.brightness), min: 0, max: 1),
            title: "Screen Brightness",
            icon: "brightness.high.fill",
            onSliderChange: { newVal in
                UIScreen.main.brightness = CGFloat(newVal)
            }
        ))

        return EnvSection(title: "INTERFACE", rows: rows)
    }

    private func buildLayoutSection() -> EnvSection {
        var rows: [EnvRow] = []

        // RTL toggle
        let isRTL = UIView.appearance().semanticContentAttribute == .forceRightToLeft
        rows.append(EnvRow(
            type: .toggle(isOn: isRTL),
            title: "RTL Layout Direction",
            subtitle: "Requires view reload to take effect",
            icon: "text.alignright",
            onToggle: { [weak self] isOn in
                let attr: UISemanticContentAttribute = isOn ? .forceRightToLeft : .forceLeftToRight
                UIView.appearance().semanticContentAttribute = attr
                self?.showToast(isOn ? "RTL Enabled — reload views to see effect" : "RTL Disabled")
            }
        ))

        // Screen info (read-only)
        let screen = UIScreen.main
        rows.append(EnvRow(
            type: .info(value: "\(Int(screen.bounds.width)) × \(Int(screen.bounds.height)) pt"),
            title: "Screen Size",
            icon: "rectangle.fill"
        ))
        rows.append(EnvRow(
            type: .info(value: "@\(Int(screen.scale))x — \(Int(screen.nativeBounds.width))×\(Int(screen.nativeBounds.height))px"),
            title: "Screen Scale / Native",
            icon: "dot.scope"
        ))
        rows.append(EnvRow(
            type: .info(value: "\(UIScreen.main.maximumFramesPerSecond) Hz"),
            title: "Refresh Rate",
            icon: "speedometer"
        ))

        return EnvSection(title: "LAYOUT & DISPLAY", rows: rows)
    }

    private func buildDynamicTypeSection() -> EnvSection {
        var rows: [EnvRow] = []

        if #available(iOS 17.0, *) {
            let sizes: [UIContentSizeCategory] = [
                .extraSmall, .small, .medium, .large,
                .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                .accessibilityMedium, .accessibilityLarge,
                .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
                .accessibilityExtraExtraExtraLarge,
            ]
            let labels = ["XS","S","M","L","XL","XXL","XXXL","aM","aL","aXL","aXXL","aXXXL"]
            let current = UIApplication.shared.preferredContentSizeCategory
            let currentIdx = sizes.firstIndex(of: current) ?? 3

            rows.append(EnvRow(
                type: .stepper(value: Double(currentIdx), min: 0, max: Double(sizes.count - 1), step: 1),
                title: "Content Size Category",
                subtitle: labels[safe: currentIdx],
                icon: "textformat.size",
                onStepperChange: { [weak self] newVal in
                    let idx = Int(newVal)
                    guard let window = PhantomPresentationResolver.activeHostWindow() else { return }
                    window.traitOverrides.preferredContentSizeCategory = sizes[idx]
                    self?.buildSections() // refresh subtitle
                }
            ))
        } else {
            rows.append(EnvRow(
                type: .info(value: UIApplication.shared.preferredContentSizeCategory.rawValue),
                title: "Content Size Category",
                subtitle: "Override available on iOS 17+",
                icon: "textformat.size"
            ))
        }

        return EnvSection(title: "DYNAMIC TYPE", rows: rows)
    }

    private func buildAccessibilitySection() -> EnvSection {
        var rows: [EnvRow] = []

        let flags: [(String, Bool, String)] = [
            ("Reduce Motion",     UIAccessibility.isReduceMotionEnabled,     "figure.walk"),
            ("Bold Text",         UIAccessibility.isBoldTextEnabled,         "bold"),
            ("Increase Contrast", UIAccessibility.isDarkerSystemColorsEnabled, "circle.lefthalf.filled"),
            ("Reduce Transparency", UIAccessibility.isReduceTransparencyEnabled, "drop.fill"),
            ("VoiceOver Running", UIAccessibility.isVoiceOverRunning,        "speaker.wave.2.fill"),
            ("Switch Control",    UIAccessibility.isSwitchControlRunning,    "arrow.2.squarepath"),
            ("Grayscale",         UIAccessibility.isGrayscaleEnabled,        "photo.fill"),
        ]

        for (name, value, icon) in flags {
            rows.append(EnvRow(
                type: .info(value: value ? "ON" : "OFF"),
                title: name,
                icon: icon,
                badgeColor: value ? UIColor.Phantom.vibrantGreen : UIColor.white.withAlphaComponent(0.25)
            ))
        }

        rows.append(EnvRow(
            type: .info(value: ""),
            title: "Open Accessibility Settings",
            icon: "gear",
            action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        ))

        return EnvSection(title: "ACCESSIBILITY (READ-ONLY)", rows: rows)
    }

    private func buildSystemSection() -> EnvSection {
        var rows: [EnvRow] = []

        rows.append(EnvRow(
            type: .info(value: "\(UIDevice.current.model) — \(UIDevice.current.systemVersion)"),
            title: "Device / OS",
            icon: "iphone"
        ))

        if #available(iOS 11.0, *) {
            let ts: (String, UIColor)
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: ts = ("Nominal", UIColor.Phantom.vibrantGreen)
            case .fair:    ts = ("Fair", UIColor.Phantom.vibrantOrange)
            case .serious: ts = ("Serious ⚠", UIColor.Phantom.vibrantOrange)
            case .critical: ts = ("Critical ⛔", UIColor.Phantom.vibrantRed)
            @unknown default: ts = ("Unknown", UIColor.white.withAlphaComponent(0.4))
            }
            rows.append(EnvRow(
                type: .info(value: ts.0),
                title: "Thermal State",
                icon: "thermometer.medium",
                badgeColor: ts.1
            ))
        }

        if #available(iOS 13.0, *) {
            let lpm = ProcessInfo.processInfo.isLowPowerModeEnabled
            rows.append(EnvRow(
                type: .info(value: lpm ? "ON" : "OFF"),
                title: "Low Power Mode",
                icon: "battery.25",
                badgeColor: lpm ? UIColor.Phantom.vibrantOrange : UIColor.white.withAlphaComponent(0.25)
            ))
        }

        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let batteryPct = device.batteryLevel >= 0 ? "\(Int(device.batteryLevel * 100))%" : "N/A"
        rows.append(EnvRow(
            type: .info(value: batteryPct),
            title: "Battery Level",
            icon: "battery.100"
        ))

        let memStr = String(format: "%.0f MB used", ProcessInfo.processInfo.physicalMemory / 1_048_576)
        rows.append(EnvRow(
            type: .info(value: memStr),
            title: "Physical Memory",
            icon: "memorychip"
        ))

        return EnvSection(title: "SYSTEM", rows: rows)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.type {
        case .toggle(let isOn):
            let cell = tableView.dequeueReusableCell(withIdentifier: "EnvToggleCell", for: indexPath) as! EnvToggleCell
            cell.configure(row: row, isOn: isOn)
            return cell
        case .slider(let value, let min, let max):
            let cell = tableView.dequeueReusableCell(withIdentifier: "EnvSliderCell", for: indexPath) as! EnvSliderCell
            cell.configure(row: row, value: value, min: min, max: max)
            return cell
        case .segment(let options, let selected):
            let cell = tableView.dequeueReusableCell(withIdentifier: "EnvSegmentCell", for: indexPath) as! EnvSegmentCell
            cell.configure(row: row, options: options, selectedIndex: selected)
            return cell
        case .stepper(let value, let min, let max, let step):
            let cell = tableView.dequeueReusableCell(withIdentifier: "EnvStepperCell", for: indexPath) as! EnvStepperCell
            cell.configure(row: row, value: value, min: min, max: max, step: step)
            return cell
        case .info(let value):
            let cell = tableView.dequeueReusableCell(withIdentifier: "EnvInfoCell", for: indexPath) as! EnvInfoCell
            cell.configure(row: row, value: value)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.type {
        case .slider, .segment, .stepper: return 72
        default: return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        56
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sections[indexPath.section].rows[indexPath.row].action?()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.4)
        header.textLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
    }

    // MARK: - Actions

    @objc private func close() { dismiss(animated: true) }

    @objc private func resetAll() {
        // Reset interface style
        if #available(iOS 13.0, *) {
            PhantomPresentationResolver.hostWindows().forEach { $0.overrideUserInterfaceStyle = .unspecified }
        }
        // Reset RTL
        UIView.appearance().semanticContentAttribute = .unspecified
        // Reset brightness (can't deterministically restore; set to 0.6 as neutral)
        UIScreen.main.brightness = 0.6
        // Reset content size (iOS 17)
        if #available(iOS 17.0, *) {
            PhantomPresentationResolver.activeHostWindow()?.traitOverrides.preferredContentSizeCategory = .unspecified
        }
        buildSections()
        showToast("Environment reset")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }
}

// MARK: - Data Models

private struct EnvSection {
    let title: String
    let rows: [EnvRow]
}

private struct EnvRow {
    enum RowType {
        case toggle(isOn: Bool)
        case slider(value: Float, min: Float, max: Float)
        case segment(options: [String], selected: Int)
        case stepper(value: Double, min: Double, max: Double, step: Double)
        case info(value: String)
    }

    let type: RowType
    let title: String
    var subtitle: String? = nil
    var icon: String = ""
    var badgeColor: UIColor? = nil
    var action: (() -> Void)? = nil
    var onToggle: ((Bool) -> Void)? = nil
    var onSliderChange: ((Float) -> Void)? = nil
    var onSegmentChange: ((Int) -> Void)? = nil
    var onStepperChange: ((Double) -> Void)? = nil
}

// MARK: - Cells

private final class EnvToggleCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; contentView.backgroundColor = .clear; selectionStyle = .none
        setupLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.Phantom.neonAzure
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        toggle.onTintColor = UIColor.Phantom.neonAzure
        toggle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggle)
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(row: EnvRow, isOn: Bool) {
        if #available(iOS 13.0, *) {
            iconView.image = UIImage(systemName: row.icon)
        }
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        subtitleLabel.isHidden = row.subtitle == nil
        toggle.isOn = isOn
        onToggle = row.onToggle
    }

    @objc private func toggled() { onToggle?(toggle.isOn) }
}

private final class EnvSliderCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private var onSliderChange: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; contentView.backgroundColor = .clear; selectionStyle = .none
        setupLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.Phantom.neonAzure
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        valueLabel.textColor = UIColor.Phantom.neonAzure
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        slider.tintColor = UIColor.Phantom.neonAzure
        slider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(slider)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            slider.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    func configure(row: EnvRow, value: Float, min: Float, max: Float) {
        if #available(iOS 13.0, *) { iconView.image = UIImage(systemName: row.icon) }
        titleLabel.text = row.title
        slider.minimumValue = min; slider.maximumValue = max; slider.value = value
        valueLabel.text = String(format: "%.0f%%", value * 100)
        onSliderChange = row.onSliderChange
    }

    @objc private func sliderChanged() {
        valueLabel.text = String(format: "%.0f%%", slider.value * 100)
        onSliderChange?(slider.value)
    }
}

private final class EnvSegmentCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let segment = UISegmentedControl()
    private var onSegmentChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; contentView.backgroundColor = .clear; selectionStyle = .none
        setupLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.Phantom.neonAzure
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        segment.tintColor = UIColor.Phantom.neonAzure
        if #available(iOS 13.0, *) {
            segment.selectedSegmentTintColor = UIColor.Phantom.neonAzure
            segment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            segment.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.5)], for: .normal)
        }
        segment.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segment)
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            segment.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            segment.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segment.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    func configure(row: EnvRow, options: [String], selectedIndex: Int) {
        if #available(iOS 13.0, *) { iconView.image = UIImage(systemName: row.icon) }
        titleLabel.text = row.title
        segment.removeAllSegments()
        for (i, opt) in options.enumerated() { segment.insertSegment(withTitle: opt, at: i, animated: false) }
        segment.selectedSegmentIndex = selectedIndex
        onSegmentChange = row.onSegmentChange
    }

    @objc private func segmentChanged() { onSegmentChange?(segment.selectedSegmentIndex) }
}

private final class EnvStepperCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    private var onStepperChange: ((Double) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; contentView.backgroundColor = .clear; selectionStyle = .none
        setupLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.Phantom.neonAzure
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        subtitleLabel.textColor = UIColor.Phantom.vibrantOrange
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        valueLabel.textColor = UIColor.Phantom.neonAzure
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        stepper.tintColor = UIColor.Phantom.neonAzure
        stepper.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepper)
        stepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            stepper.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            subtitleLabel.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),
        ])
    }

    func configure(row: EnvRow, value: Double, min: Double, max: Double, step: Double) {
        if #available(iOS 13.0, *) { iconView.image = UIImage(systemName: row.icon) }
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        stepper.minimumValue = min; stepper.maximumValue = max
        stepper.stepValue = step; stepper.value = value
        valueLabel.text = String(format: "%.0f", value)
        onStepperChange = row.onStepperChange
    }

    @objc private func stepperChanged() {
        valueLabel.text = String(format: "%.0f", stepper.value)
        onStepperChange?(stepper.value)
    }
}

private final class EnvInfoCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; contentView.backgroundColor = .clear
        selectionStyle = .default
        setupLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.white.withAlphaComponent(0.35)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        valueLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -13),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160),
        ])
    }

    func configure(row: EnvRow, value: String) {
        if #available(iOS 13.0, *) { iconView.image = UIImage(systemName: row.icon) }
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        subtitleLabel.isHidden = row.subtitle == nil
        valueLabel.text = value

        if let badgeColor = row.badgeColor {
            valueLabel.textColor = badgeColor
        } else {
            valueLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        }

        if row.action != nil {
            accessoryType = .disclosureIndicator
        } else {
            accessoryType = .none
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#endif
