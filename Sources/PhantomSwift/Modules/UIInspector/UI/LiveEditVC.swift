#if DEBUG
import UIKit

/// Live property editor for a selected UIView.
/// Provides sliders, steppers, color swatches, and segmented controls for real-time editing.
internal final class LiveEditVC: UIViewController {

    private let targetView: UIView
    private let tableView = UITableView(frame: .zero, style: .grouped)

    // Saved originals for reset
    private lazy var originalFrame = targetView.frame
    private lazy var originalAlpha = targetView.alpha
    private lazy var originalCornerRadius = targetView.layer.cornerRadius
    private lazy var originalBorderWidth = targetView.layer.borderWidth
    private lazy var originalBackgroundColor = targetView.backgroundColor

    private enum SectionKind: Int, CaseIterable {
        case geometry, visual, layer, labelProps, imageViewProps

        var title: String {
            switch self {
            case .geometry: return "GEOMETRY"
            case .visual: return "VISUAL"
            case .layer: return "LAYER"
            case .labelProps: return "UILABEL"
            case .imageViewProps: return "UIIMAGEVIEW"
            }
        }
    }

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Live Edit"
        setupAppearance()
        setupNavigation()
        setupTableView()
    }

    private func setupAppearance() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }

    private func setupNavigation() {
        // "Done" — only needed when presented modally (no system back button)
        if navigationController?.viewControllers.first === self {
            if #available(iOS 13.0, *) {
                navigationItem.leftBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "xmark.circle.fill"),
                    style: .plain, target: self, action: #selector(dismiss(_:)))
            } else {
                navigationItem.leftBarButtonItem = UIBarButtonItem(
                    title: "Done", style: .done, target: self, action: #selector(dismiss(_:)))
            }
            navigationItem.leftBarButtonItem?.tintColor = UIColor.Phantom.neonAzure
        }

        // "Reset" — always shown on the right
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.counterclockwise"),
                style: .plain, target: self, action: #selector(resetChanges))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Reset", style: .plain, target: self, action: #selector(resetChanges))
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantOrange
    }

    @objc private func dismiss(_ sender: Any) {
        dismiss(animated: true)
    }

    @objc private func resetChanges() {
        targetView.frame = originalFrame
        targetView.alpha = originalAlpha
        targetView.layer.cornerRadius = originalCornerRadius
        targetView.layer.borderWidth = originalBorderWidth
        targetView.backgroundColor = originalBackgroundColor
        tableView.reloadData()
        showToast("Restored to original")
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SliderEditCell.self, forCellReuseIdentifier: SliderEditCell.reuseID)
        tableView.register(StepperEditCell.self, forCellReuseIdentifier: StepperEditCell.reuseID)
        tableView.register(ColorSwatchCell.self, forCellReuseIdentifier: ColorSwatchCell.reuseID)
        tableView.register(SegmentedEditCell.self, forCellReuseIdentifier: SegmentedEditCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func activeSections() -> [SectionKind] {
        var sections: [SectionKind] = [.geometry, .visual, .layer]
        if targetView is UILabel { sections.append(.labelProps) }
        if targetView is UIImageView { sections.append(.imageViewProps) }
        return sections
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
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension LiveEditVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { activeSections().count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch activeSections()[section] {
        case .geometry:     return 4  // x, y, width, height
        case .visual:       return 2  // alpha, backgroundColor
        case .layer:        return 2  // cornerRadius, borderWidth
        case .labelProps:   return 3  // fontSize, textAlignment, numberOfLines
        case .imageViewProps: return 1  // contentMode
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = activeSections()[indexPath.section]

        switch section {
        case .geometry:
            let cell = tableView.dequeueReusableCell(withIdentifier: StepperEditCell.reuseID, for: indexPath) as! StepperEditCell
            switch indexPath.row {
            case 0:
                cell.configure(label: "X", value: Double(targetView.frame.origin.x), step: 1, min: -9999, max: 9999) { [weak self] val in
                    guard let self else { return }
                    var f = self.targetView.frame; f.origin.x = CGFloat(val); self.targetView.frame = f
                }
            case 1:
                cell.configure(label: "Y", value: Double(targetView.frame.origin.y), step: 1, min: -9999, max: 9999) { [weak self] val in
                    guard let self else { return }
                    var f = self.targetView.frame; f.origin.y = CGFloat(val); self.targetView.frame = f
                }
            case 2:
                cell.configure(label: "Width", value: Double(targetView.frame.width), step: 1, min: 0, max: 4000) { [weak self] val in
                    guard let self else { return }
                    var f = self.targetView.frame; f.size.width = CGFloat(val); self.targetView.frame = f
                }
            case 3:
                cell.configure(label: "Height", value: Double(targetView.frame.height), step: 1, min: 0, max: 4000) { [weak self] val in
                    guard let self else { return }
                    var f = self.targetView.frame; f.size.height = CGFloat(val); self.targetView.frame = f
                }
            default: break
            }
            return cell

        case .visual:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: SliderEditCell.reuseID, for: indexPath) as! SliderEditCell
                cell.configure(label: "Alpha", value: Float(targetView.alpha), min: 0, max: 1,
                               color: UIColor.Phantom.vibrantPurple, format: "%.2f") { [weak self] val in
                    self?.targetView.alpha = CGFloat(val)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ColorSwatchCell.reuseID, for: indexPath) as! ColorSwatchCell
                cell.configure(label: "Background Color", color: targetView.backgroundColor ?? .clear) { [weak self] color in
                    self?.targetView.backgroundColor = color
                }
                return cell
            }

        case .layer:
            let cell = tableView.dequeueReusableCell(withIdentifier: SliderEditCell.reuseID, for: indexPath) as! SliderEditCell
            if indexPath.row == 0 {
                cell.configure(label: "Corner Radius", value: Float(targetView.layer.cornerRadius),
                               min: 0, max: 100, color: UIColor.Phantom.vibrantOrange, format: "%.0f") { [weak self] val in
                    self?.targetView.layer.cornerRadius = CGFloat(val)
                    if #available(iOS 13.0, *) { self?.targetView.layer.cornerCurve = .continuous }
                }
            } else {
                cell.configure(label: "Border Width", value: Float(targetView.layer.borderWidth),
                               min: 0, max: 20, color: UIColor.Phantom.vibrantGreen, format: "%.1f") { [weak self] val in
                    self?.targetView.layer.borderWidth = CGFloat(val)
                }
            }
            return cell

        case .labelProps:
            guard let label = targetView as? UILabel else { return UITableViewCell() }
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: SliderEditCell.reuseID, for: indexPath) as! SliderEditCell
                cell.configure(label: "Font Size", value: Float(label.font.pointSize),
                               min: 6, max: 72, color: UIColor.Phantom.neonAzure, format: "%.0f") { val in
                    label.font = label.font.withSize(CGFloat(val))
                }
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedEditCell.reuseID, for: indexPath) as! SegmentedEditCell
                cell.configure(label: "Text Align", items: ["Left", "Center", "Right", "Justified"],
                               selectedIndex: label.textAlignment.rawValue) { idx in
                    label.textAlignment = NSTextAlignment(rawValue: idx) ?? .natural
                }
                return cell
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: StepperEditCell.reuseID, for: indexPath) as! StepperEditCell
                cell.configure(label: "# Lines", value: Double(label.numberOfLines), step: 1, min: 0, max: 20) { val in
                    label.numberOfLines = Int(val)
                }
                return cell
            default: return UITableViewCell()
            }

        case .imageViewProps:
            guard let iv = targetView as? UIImageView else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedEditCell.reuseID, for: indexPath) as! SegmentedEditCell
            let modes: [UIView.ContentMode] = [.scaleToFill, .scaleAspectFit, .scaleAspectFill, .center, .top, .bottom]
            let modeNames = ["Fill", "AspectFit", "AspectFill", "Center", "Top", "Bottom"]
            let currentIdx = modes.firstIndex(of: iv.contentMode) ?? 1
            cell.configure(label: "Content Mode", items: modeNames, selectedIndex: currentIdx) { idx in
                iv.contentMode = modes[safe: idx] ?? .scaleAspectFit
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        activeSections()[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.4)
        header.textLabel?.font = UIFont.systemFont(ofSize: 10, weight: .black)
    }
}

// MARK: - Slider Cell

final class SliderEditCell: UITableViewCell {
    static let reuseID = "SliderEditCell"

    private let nameLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private var onChange: ((Float) -> Void)?
    private var format: String = "%.2f"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.textColor = UIColor.Phantom.neonAzure
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [nameLabel, valueLabel, slider].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            valueLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),
            slider.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(label: String, value: Float, min: Float, max: Float,
                   color: UIColor, format: String = "%.2f", onChange: @escaping (Float) -> Void) {
        self.format = format
        self.onChange = onChange
        nameLabel.text = label
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.minimumTrackTintColor = color
        valueLabel.textColor = color
        valueLabel.text = String(format: format, value)
    }

    @objc private func sliderChanged() {
        valueLabel.text = String(format: format, slider.value)
        onChange?(slider.value)
    }
}

// MARK: - Stepper Cell

final class StepperEditCell: UITableViewCell {
    static let reuseID = "StepperEditCell"

    private let nameLabel = UILabel()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    private var onChange: ((Double) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = UIColor.Phantom.neonAzure
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        stepper.tintColor = UIColor.Phantom.neonAzure
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)

        [nameLabel, valueLabel, stepper].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 56),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(label: String, value: Double, step: Double, min: Double, max: Double,
                   onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        nameLabel.text = label
        stepper.minimumValue = min
        stepper.maximumValue = max
        stepper.stepValue = step
        stepper.value = value
        valueLabel.text = String(format: "%.0f", value)
    }

    @objc private func stepperChanged() {
        valueLabel.text = String(format: "%.0f", stepper.value)
        onChange?(stepper.value)
    }
}

// MARK: - Color Swatch Cell

final class ColorSwatchCell: UITableViewCell {
    static let reuseID = "ColorSwatchCell"

    private let nameLabel = UILabel()
    private let swatchView = UIView()
    private let hexLabel = UILabel()
    private let scrollView = UIScrollView()
    private let swatchStack = UIStackView()
    private var onColorChange: ((UIColor) -> Void)?

    private let presetColors: [(name: String, color: UIColor)] = [
        ("Clear",  .clear),
        ("White",  .white),
        ("Black",  .black),
        ("Red",    .systemRed),
        ("Orange", .systemOrange),
        ("Yellow", .systemYellow),
        ("Green",  .systemGreen),
        ("Blue",   .systemBlue),
        ("Purple", .systemPurple),
        ("Indigo", UIColor.Phantom.electricIndigo),
        ("Cyan",   UIColor.Phantom.neonAzure),
    ]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        swatchView.layer.cornerRadius = 8
        swatchView.layer.borderWidth = 1
        swatchView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        swatchView.translatesAutoresizingMaskIntoConstraints = false

        hexLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        hexLabel.textColor = UIColor.Phantom.neonAzure
        hexLabel.translatesAutoresizingMaskIntoConstraints = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        swatchStack.axis = .horizontal
        swatchStack.spacing = 8
        swatchStack.translatesAutoresizingMaskIntoConstraints = false

        presetColors.forEach { item in
            let btn = UIButton(type: .system)
            btn.backgroundColor = item.color
            btn.layer.cornerRadius = 14
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            btn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 28),
                btn.heightAnchor.constraint(equalToConstant: 28),
            ])
            btn.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            swatchStack.addArrangedSubview(btn)
        }

        scrollView.addSubview(swatchStack)
        [nameLabel, swatchView, hexLabel, scrollView].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            swatchView.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            swatchView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            swatchView.widthAnchor.constraint(equalToConstant: 24),
            swatchView.heightAnchor.constraint(equalToConstant: 24),
            hexLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            hexLabel.trailingAnchor.constraint(equalTo: swatchView.leadingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.heightAnchor.constraint(equalToConstant: 36),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            swatchStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            swatchStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            swatchStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            swatchStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            swatchStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    func configure(label: String, color: UIColor, onChange: @escaping (UIColor) -> Void) {
        nameLabel.text = label
        swatchView.backgroundColor = color
        hexLabel.text = color.hexString
        onColorChange = onChange
    }

    @objc private func presetTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        swatchView.backgroundColor = color
        hexLabel.text = color.hexString
        onColorChange?(color)
    }
}

// MARK: - Segmented Control Cell

final class SegmentedEditCell: UITableViewCell {
    static let reuseID = "SegmentedEditCell"

    private let nameLabel = UILabel()
    private let segmented = UISegmentedControl()
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        segmented.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            segmented.selectedSegmentTintColor = UIColor.Phantom.neonAzure
        }
        segmented.addTarget(self, action: #selector(segChanged), for: .valueChanged)

        [nameLabel, segmented].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmented.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            segmented.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmented.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segmented.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(label: String, items: [String], selectedIndex: Int, onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        nameLabel.text = label
        segmented.removeAllSegments()
        items.enumerated().forEach { idx, item in
            segmented.insertSegment(withTitle: item, at: idx, animated: false)
        }
        segmented.selectedSegmentIndex = min(selectedIndex, items.count - 1)
    }

    @objc private func segChanged() { onChange?(segmented.selectedSegmentIndex) }
}

// MARK: - Private Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
