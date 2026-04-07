#if DEBUG
import UIKit

// MARK: - GridOverlayVC

/// Settings panel for PhantomGridOverlay.
/// All controls update the live overlay in real time via PhantomGridOverlay.shared.update(_:).
internal final class GridOverlayVC: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var isOverlayOn = PhantomGridOverlay.shared.isVisible

    // Live preview toggle state (so we can enable the overlay while in this VC)
    private var localConfig = PhantomGridOverlay.shared.config

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case toggle, presets, columns, spacing, baseline, guides
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grid Overlay"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        applyNavBarStyle()
        setupNavItems()
        setupTableView()
    }

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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reset", style: .plain, target: self, action: #selector(resetDefaults))
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantOrange
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.07)
        tableView.separatorInset  = UIEdgeInsets(top: 0, left: 48, bottom: 0, right: 0)
        tableView.dataSource      = self
        tableView.delegate        = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Base")
        tableView.register(ToggleCell.self, forCellReuseIdentifier: "ToggleCell")
        tableView.register(SliderCell.self, forCellReuseIdentifier: "SliderCell")
        tableView.register(StepperCell.self, forCellReuseIdentifier: "StepperCell")
        tableView.register(PresetButtonsCell.self, forCellReuseIdentifier: "PresetButtonsCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Config Update

    private func apply(_ mutation: (inout PhantomGridConfig) -> Void) {
        mutation(&localConfig)
        if isOverlayOn {
            PhantomGridOverlay.shared.update(mutation)
        }
    }

    // MARK: - Actions

    @objc private func handleDone() {
        // Persist final config
        PhantomGridOverlay.shared.update { $0 = self.localConfig }
        dismiss(animated: true)
    }

    @objc private func resetDefaults() {
        localConfig = PhantomGridConfig()
        apply { $0 = PhantomGridConfig() }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension GridOverlayVC: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .toggle:   return 2   // Show/Hide overlay + Touch Visualizer shortcut
        case .presets:  return 1   // column-count preset buttons row
        case .columns:  return 1   // column count stepper
        case .spacing:  return 2   // margin + gutter sliders
        case .baseline: return 2   // show baseline toggle + spacing slider
        case .guides:   return 1   // center guides toggle
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (Section(rawValue: indexPath.section)!, indexPath.row) {
        case (.toggle, let row):
            return configureToggleCell(for: tableView, at: indexPath, row: row)
        case (.presets, _):
            return configurePresetsCell(for: tableView, at: indexPath)
        case (.columns, _):
            return configureColumnsCell(for: tableView, at: indexPath)
        case (.spacing, let row):
            return configureSpacingCell(for: tableView, at: indexPath, row: row)
        case (.baseline, let row):
            return configureBaselineCell(for: tableView, at: indexPath, row: row)
        case (.guides, _):
            return configureGuidesCell(for: tableView, at: indexPath)
        default:
            return tableView.dequeueReusableCell(withIdentifier: "Base", for: indexPath)
        }
    }

    private func configureToggleCell(for tableView: UITableView, at indexPath: IndexPath, row: Int) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
        if row == 0 {
            cell.configure(label: "Show Grid Overlay",
                           icon: "squareshape.split.3x3",
                           iconColor: UIColor.Phantom.neonAzure,
                           isOn: isOverlayOn)
            cell.onToggle = { [weak self] isOn in
                self?.isOverlayOn = isOn
                isOn ? PhantomGridOverlay.shared.show()
                     : PhantomGridOverlay.shared.hide()
                if isOn { PhantomGridOverlay.shared.update { [weak self] cfg in
                    cfg = self?.localConfig ?? PhantomGridConfig()
                } }
            }
        } else {
            cell.configure(label: "Touch Visualizer",
                           icon: "hand.tap",
                           iconColor: UIColor.Phantom.vibrantOrange,
                           isOn: PhantomTouchVisualizer.shared.isActive)
            cell.onToggle = { isOn in
                isOn ? PhantomTouchVisualizer.shared.start()
                     : PhantomTouchVisualizer.shared.stop()
            }
        }
        return cell
    }

    private func configurePresetsCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PresetButtonsCell", for: indexPath) as! PresetButtonsCell
        cell.configure(presets: [
            Preset(label: "4-col\niOS HIG",  columns: 4,  margin: 20, gutter: 16),
            Preset(label: "8-col\nMaterial",  columns: 8,  margin: 16, gutter: 8),
            Preset(label: "12-col\nBootstrap", columns: 12, margin: 16, gutter: 8),
            Preset(label: "16-col\nDesktop",  columns: 16, margin: 16, gutter: 4)
        ])
        cell.onPresetSelected = { [weak self] preset in
            self?.apply {
                $0.columns = preset.columns
                $0.margin  = preset.margin
                $0.gutter  = preset.gutter
            }
            self?.tableView.reloadSections(
                IndexSet(integersIn: Section.columns.rawValue...Section.spacing.rawValue),
                with: .none)
        }
        return cell
    }

    private func configureColumnsCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StepperCell", for: indexPath) as! StepperCell
        cell.configure(with: .init(
            label: "Columns",
            icon: "rectangle.split.3x1",
            iconColor: UIColor.Phantom.vibrantGreen,
            value: Double(localConfig.columns),
            minValue: 1, maxValue: 24, step: 1))
        cell.onChange = { [weak self] val in
            self?.apply { $0.columns = Int(val) }
        }
        return cell
    }

    private func configureSpacingCell(for tableView: UITableView, at indexPath: IndexPath, row: Int) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
        if row == 0 {
            cell.configure(with: .init(
                label: "Margin",
                icon: "arrow.left.and.right",
                iconColor: UIColor.Phantom.vibrantPurple,
                value: Float(localConfig.margin),
                min: 0, max: 60, format: "%.0f pt"))
            cell.onChange = { [weak self] val in
                self?.apply { $0.margin = CGFloat(val) }
            }
        } else {
            cell.configure(with: .init(
                label: "Gutter",
                icon: "equal.square",
                iconColor: UIColor.Phantom.vibrantPurple,
                value: Float(localConfig.gutter),
                min: 0, max: 40, format: "%.0f pt"))
            cell.onChange = { [weak self] val in
                self?.apply { $0.gutter = CGFloat(val) }
            }
        }
        return cell
    }

    private func configureBaselineCell(for tableView: UITableView, at indexPath: IndexPath, row: Int) -> UITableViewCell {
        if row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(label: "Baseline Grid",
                           icon: "line.3.horizontal",
                           iconColor: UIColor.Phantom.vibrantOrange,
                           isOn: localConfig.showBaseline)
            cell.onToggle = { [weak self] isOn in
                self?.apply { $0.showBaseline = isOn }
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
            cell.configure(with: .init(
                label: "Baseline Spacing",
                icon: "timeline.selection",
                iconColor: UIColor.Phantom.vibrantOrange,
                value: Float(localConfig.baselineSpacing),
                min: 4, max: 32, format: "%.0f pt"))
            cell.onChange = { [weak self] val in
                self?.apply { $0.baselineSpacing = CGFloat(val) }
            }
            return cell
        }
    }

    private func configureGuidesCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
        cell.configure(label: "Center Guides",
                       icon: "plus.viewfinder",
                       iconColor: UIColor.Phantom.neonAzure,
                       isOn: localConfig.showCenterGuides)
        cell.onToggle = { [weak self] isOn in
            self?.apply { $0.showCenterGuides = isOn }
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension GridOverlayVC: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titles = ["OVERLAY", "PRESETS", "COLUMNS", "SPACING", "BASELINE", "GUIDES"]
        guard section < titles.count else { return nil }
        return sectionHeader(titles[section])
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 32 }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == Section.presets.rawValue { return 96 }
        return 56
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func sectionHeader(_ title: String) -> UIView {
        let v = UIView()
        v.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.5)
        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 9.5, weight: .black)
        lbl.textColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.8)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 48),
            lbl.centerYAnchor.constraint(equalTo: v.centerYAnchor)
        ])
        return v
    }
}

// MARK: - Preset Model

private struct Preset {
    let label: String
    let columns: Int
    let margin: CGFloat
    let gutter: CGFloat
}

// MARK: - ToggleCell

private final class ToggleCell: UITableViewCell {
    var onToggle: ((Bool) -> Void)?
    private let iconView  = UIView()
    private let iconImage = UIImageView()
    private let titleLbl  = UILabel()
    private let toggle    = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        iconImage.contentMode = .scaleAspectFit
        iconImage.tintColor   = .white
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImage)

        titleLbl.font      = .systemFont(ofSize: 14, weight: .medium)
        titleLbl.textColor = .white
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        toggle.onTintColor = UIColor.Phantom.neonAzure
        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggle)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            iconImage.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 16),
            iconImage.heightAnchor.constraint(equalToConstant: 16),
            titleLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLbl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, icon: String, iconColor: UIColor, isOn: Bool) {
        titleLbl.text     = label
        iconView.backgroundColor = iconColor.withAlphaComponent(0.15)
        toggle.isOn       = isOn
        if #available(iOS 13.0, *) {
            iconImage.image = UIImage(systemName: icon)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
            iconImage.tintColor = iconColor
        } else {
            iconImage.isHidden = true
        }
    }

    @objc private func switched() { onToggle?(toggle.isOn) }
}

// MARK: - SliderCell

private final class SliderCell: UITableViewCell {
    var onChange: ((Float) -> Void)?
    private let iconView   = UIView()
    private let iconImage  = UIImageView()
    private let titleLbl   = UILabel()
    private let valueLbl   = UILabel()
    private let slider     = UISlider()
    private var fmt        = "%.0f pt"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImage)

        titleLbl.font      = .systemFont(ofSize: 13, weight: .medium)
        titleLbl.textColor = .white
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        valueLbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        valueLbl.textColor = UIColor.Phantom.neonAzure
        valueLbl.textAlignment = .right
        valueLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLbl)

        slider.minimumTrackTintColor = UIColor.Phantom.neonAzure
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15)
        slider.addTarget(self, action: #selector(slid), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(slider)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            iconImage.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 16),
            iconImage.heightAnchor.constraint(equalToConstant: 16),
            titleLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLbl.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            valueLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLbl.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            valueLbl.widthAnchor.constraint(equalToConstant: 56),
            slider.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    struct Configuration {
        let label: String
        let icon: String
        let iconColor: UIColor
        let value: Float
        let min: Float
        let max: Float
        let format: String
    }

    func configure(with config: Configuration) {
        fmt = config.format
        titleLbl.text = config.label
        iconView.backgroundColor = config.iconColor.withAlphaComponent(0.15)
        if #available(iOS 13.0, *) {
            iconImage.image = UIImage(systemName: config.icon)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
            iconImage.tintColor = config.iconColor
        }
        slider.minimumValue = config.min
        slider.maximumValue = config.max
        slider.value        = config.value
        valueLbl.text       = String(format: fmt, config.value)
    }

    @objc private func slid() {
        valueLbl.text = String(format: fmt, slider.value)
        onChange?(slider.value)
    }
}

// MARK: - StepperCell

private final class StepperCell: UITableViewCell {
    var onChange: ((Double) -> Void)?
    private let iconView  = UIView()
    private let iconImage = UIImageView()
    private let titleLbl  = UILabel()
    private let valueLbl  = UILabel()
    private let stepper   = UIStepper()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImage)

        titleLbl.font = .systemFont(ofSize: 14, weight: .medium)
        titleLbl.textColor = .white
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        valueLbl.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .black)
        valueLbl.textColor = UIColor.Phantom.neonAzure
        valueLbl.textAlignment = .center
        valueLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLbl)

        stepper.tintColor = UIColor.Phantom.neonAzure
        stepper.addTarget(self, action: #selector(stepped), for: .valueChanged)
        stepper.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepper)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            iconImage.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 16),
            iconImage.heightAnchor.constraint(equalToConstant: 16),
            titleLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLbl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLbl.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -12),
            valueLbl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLbl.widthAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    struct Configuration {
        let label: String
        let icon: String
        let iconColor: UIColor
        let value: Double
        let minValue: Double
        let maxValue: Double
        let step: Double
    }

    func configure(with config: Configuration) {
        titleLbl.text = config.label
        iconView.backgroundColor = config.iconColor.withAlphaComponent(0.15)
        if #available(iOS 13.0, *) {
            iconImage.image = UIImage(systemName: config.icon)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
            iconImage.tintColor = config.iconColor
        }
        stepper.minimumValue = config.minValue
        stepper.maximumValue = config.maxValue
        stepper.stepValue    = config.step
        stepper.value        = config.value
        valueLbl.text        = "\(Int(config.value))"
    }

    @objc private func stepped() {
        valueLbl.text = "\(Int(stepper.value))"
        onChange?(stepper.value)
    }
}

// MARK: - PresetButtonsCell

private final class PresetButtonsCell: UITableViewCell {
    var onPresetSelected: ((Preset) -> Void)?
    private let stack = UIStackView()
    private var presets: [Preset] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        stack.axis         = .horizontal
        stack.spacing      = 8
        stack.distribution = .fillEqually
        stack.alignment    = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(presets: [Preset]) {
        self.presets = presets
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, preset) in presets.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(preset.label, for: .normal)
            btn.titleLabel?.font          = .systemFont(ofSize: 11, weight: .bold)
            btn.titleLabel?.numberOfLines = 2
            btn.titleLabel?.textAlignment = .center
            btn.setTitleColor(UIColor.Phantom.neonAzure, for: .normal)
            btn.backgroundColor        = UIColor.Phantom.neonAzure.withAlphaComponent(0.1)
            btn.layer.cornerRadius     = 10
            btn.layer.borderWidth      = 1
            btn.layer.borderColor      = UIColor.Phantom.neonAzure.withAlphaComponent(0.3).cgColor
            btn.tag                    = idx
            btn.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }
    }

    @objc private func presetTapped(_ sender: UIButton) {
        guard sender.tag < presets.count else { return }
        onPresetSelected?(presets[sender.tag])
    }
}

#endif
