#if DEBUG
import UIKit

// MARK: - EnvironmentDashboardVC

/// Modern Environment Relay dashboard — spoof locale, GPS, thermal, battery, and UI style.
internal final class EnvironmentDashboardVC: UIViewController {

    // MARK: - Stored UI References (for targeted, efficient updates)

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    // BIOS header labels
    private let modelLabel = UILabel()
    private let osLabel    = UILabel()
    private let diskLabel  = UILabel()
    private let memLabel   = UILabel()
    private let resLabel   = UILabel()

    // Locale — code → button map
    private let langCodes  = ["en", "id", "ja", "ar"]
    private let langNames  = ["EN", "ID", "JA", "AR"]
    private var langButtons: [String: UIButton] = [:]

    // GPS — one container view per location entry
    private var locationRows: [UIView] = []

    // Battery — stored properties for O(1) live update
    private let batteryValueLabel = UILabel()
    private let batterySlider     = UISlider()

    // Font scale
    private let fontScaleValues: [CGFloat] = [0.8, 1.0, 1.2, 1.5]
    private let fontScaleNames:  [String]  = ["XS", "DEF", "LG", "XL"]
    private var fontScaleButtons: [UIButton] = []

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadHeaderData()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSystemStateChanged),
            name: .phantomSystemStateChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onLocationChanged),
            name: .phantomLocationChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavBar()
    }

    // MARK: - Nav Bar

    private func applyNavBar() {
        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()
            a.backgroundColor = PhantomTheme.shared.backgroundColor
            a.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold),
            ]
            navigationController?.navigationBar.standardAppearance   = a
            navigationController?.navigationBar.scrollEdgeAppearance = a
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }

    // MARK: - Root Layout

    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Environment Relay"

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis    = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        buildBIOSHeader()
        buildLocalizationCard()
        buildGPSCard()
        buildThermalCard()
        buildBatteryCard()
        buildFontScaleCard()
        buildUIStyleCard()
    }

    // MARK: - BIOS Header

    private func buildBIOSHeader() {
        let card = makeCard()

        let dot = UIView()
        dot.backgroundColor   = UIColor.Phantom.neonAzure
        dot.layer.cornerRadius = 4

        let titleLbl = UILabel()
        titleLbl.text      = "HARDWARE  //  ENVIRONMENT_MANAGER v5.0"
        titleLbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        titleLbl.textColor = UIColor.Phantom.neonAzure

        let titleRow = UIStackView(arrangedSubviews: [dot, titleLbl])
        titleRow.axis      = .horizontal
        titleRow.spacing   = 8
        titleRow.alignment = .center

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        NSLayoutConstraint.activate([divider.heightAnchor.constraint(equalToConstant: 1)])

        let statsStack = UIStackView()
        statsStack.axis    = .vertical
        statsStack.spacing = 5
        for lbl in [modelLabel, osLabel, diskLabel, memLabel, resLabel] {
            lbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            lbl.textColor = UIColor.white.withAlphaComponent(0.65)
            statsStack.addArrangedSubview(lbl)
        }

        let vStack = UIStackView(arrangedSubviews: [titleRow, divider, statsStack])
        vStack.axis    = .vertical
        vStack.spacing = 12
        vStack.isLayoutMarginsRelativeArrangement = true
        vStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        // Pulse the beacon dot
        UIView.animate(withDuration: 1.0, delay: 0,
                       options: [.autoreverse, .repeat, .curveEaseInOut]) { dot.alpha = 0.2 }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Localization Card

    private func buildLocalizationCard() {
        let (card, inner) = makeSectionCard(title: "LOCALIZATION OVERRIDE",
                                            accent: UIColor.Phantom.vibrantPurple,
                                            symbol: "globe")
        let grid = UIStackView()
        grid.axis = .horizontal; grid.distribution = .fillEqually; grid.spacing = 8

        for (idx, code) in langCodes.enumerated() {
            let isActive = PhantomLocaleManager.shared.currentLanguage == code
            let btn = makePill(title: langNames[idx], active: isActive, color: UIColor.Phantom.vibrantPurple)
            btn.tag = idx
            btn.addTarget(self, action: #selector(languageTapped(_:)), for: .touchUpInside)
            langButtons[code] = btn
            grid.addArrangedSubview(btn)
        }

        let note = makeNote("⚠  Language changes may require app restart to fully take effect.")
        [grid, note].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - GPS Card

    private func buildGPSCard() {
        let (card, inner) = makeSectionCard(title: "GPS RELAY  //  LOCATION SPOOFING",
                                            accent: UIColor.Phantom.vibrantGreen,
                                            symbol: "location.fill")
        let locations = PhantomLocationManager.shared.mockLocations
        let selected  = PhantomLocationManager.shared.selectedLocation

        locationRows = []
        let locStack  = UIStackView(); locStack.axis = .vertical; locStack.spacing = 6

        for (idx, loc) in locations.enumerated() {
            let row = buildLocationRow(location: loc, index: idx, isActive: selected == loc)
            locationRows.append(row); locStack.addArrangedSubview(row)
        }

        if locations.isEmpty {
            let empty = UILabel()
            empty.text = "No mock locations configured."
            empty.font = UIFont.systemFont(ofSize: 13); empty.textColor = UIColor.white.withAlphaComponent(0.35)
            locStack.addArrangedSubview(empty)
        }

        let resetBtn = UIButton(type: .system)
        resetBtn.setTitle("↩  RESET TO HARDWARE GPS", for: .normal)
        resetBtn.setTitleColor(UIColor.Phantom.vibrantRed, for: .normal)
        resetBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        resetBtn.contentHorizontalAlignment = .left
        resetBtn.addTarget(self, action: #selector(resetLocation), for: .touchUpInside)

        [locStack, resetBtn].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    private func buildLocationRow(location: PhantomLocation, index: Int, isActive: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor  = isActive
            ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.12)
            : UIColor.white.withAlphaComponent(0.04)
        container.layer.cornerRadius = 10
        container.layer.borderWidth  = 1
        container.layer.borderColor  = isActive
            ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.4).cgColor
            : UIColor.white.withAlphaComponent(0.06).cgColor

        let iconPill = UIView()
        iconPill.backgroundColor   = isActive
            ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.2)
            : UIColor.white.withAlphaComponent(0.07)
        iconPill.layer.cornerRadius = 9
        iconPill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconPill.widthAnchor.constraint(equalToConstant: 36),
            iconPill.heightAnchor.constraint(equalToConstant: 36),
        ])

        if #available(iOS 13.0, *) {
            let img = UIImageView(image: UIImage(systemName: isActive ? "location.fill" : "location"))
            img.tintColor = isActive ? UIColor.Phantom.vibrantGreen : UIColor.white.withAlphaComponent(0.35)
            img.contentMode = .scaleAspectFit
            img.translatesAutoresizingMaskIntoConstraints = false
            iconPill.addSubview(img)
            NSLayoutConstraint.activate([
                img.centerXAnchor.constraint(equalTo: iconPill.centerXAnchor),
                img.centerYAnchor.constraint(equalTo: iconPill.centerYAnchor),
                img.widthAnchor.constraint(equalToConstant: 16),
                img.heightAnchor.constraint(equalToConstant: 16),
            ])
        } else {
            let lbl = UILabel()
            lbl.text = isActive ? "●" : "○"
            lbl.textColor = isActive ? UIColor.Phantom.vibrantGreen : UIColor.white.withAlphaComponent(0.35)
            lbl.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            iconPill.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerXAnchor.constraint(equalTo: iconPill.centerXAnchor),
                lbl.centerYAnchor.constraint(equalTo: iconPill.centerYAnchor),
            ])
        }

        let nameLbl = UILabel()
        nameLbl.text = location.name
        nameLbl.font = UIFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .regular)
        nameLbl.textColor = isActive ? .white : UIColor.white.withAlphaComponent(0.7)

        let coordLbl = UILabel()
        coordLbl.text      = String(format: "%.4f°,  %.4f°", location.latitude, location.longitude)
        coordLbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        coordLbl.textColor = UIColor.white.withAlphaComponent(0.3)

        let textStack = UIStackView(arrangedSubviews: [nameLbl, coordLbl])
        textStack.axis = .vertical; textStack.spacing = 2

        let rowStack = UIStackView(arrangedSubviews: [iconPill, textStack])
        rowStack.axis = .horizontal; rowStack.spacing = 12; rowStack.alignment = .center
        rowStack.isLayoutMarginsRelativeArrangement = true
        rowStack.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowStack)

        let tapBtn = UIButton()
        tapBtn.tag = index
        tapBtn.addTarget(self, action: #selector(locationTapped(_:)), for: .touchUpInside)
        tapBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tapBtn)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tapBtn.topAnchor.constraint(equalTo: container.topAnchor),
            tapBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tapBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tapBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Thermal Card

    private func buildThermalCard() {
        let (card, inner) = makeSectionCard(title: "THERMAL STATE SIMULATION",
                                            accent: UIColor.Phantom.vibrantOrange,
                                            symbol: "thermometer.medium")
        let ctrl = UISegmentedControl(items: ["Nominal", "Fair", "Serious", "Critical"])
        styleSegmented(ctrl, accent: UIColor.Phantom.vibrantOrange)
        switch PhantomEnvironmentMonitor.shared.thermalState {
        case .nominal:  ctrl.selectedSegmentIndex = 0
        case .fair:     ctrl.selectedSegmentIndex = 1
        case .serious:  ctrl.selectedSegmentIndex = 2
        case .critical: ctrl.selectedSegmentIndex = 3
        @unknown default: ctrl.selectedSegmentIndex = 0
        }
        ctrl.addTarget(self, action: #selector(thermalChanged(_:)), for: .valueChanged)

        let hintRow = UIStackView(); hintRow.axis = .horizontal; hintRow.distribution = .fillEqually
        for (text, color) in [("● Safe", UIColor.white.withAlphaComponent(0.35)),
                               ("● Warn", UIColor.Phantom.vibrantOrange),
                               ("● Alert", UIColor.orange),
                               ("● CRIT",  UIColor.Phantom.vibrantRed)] {
            let lbl = UILabel()
            lbl.text = text; lbl.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
            lbl.textColor = color; lbl.textAlignment = .center
            hintRow.addArrangedSubview(lbl)
        }

        [ctrl, hintRow].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Battery Card

    private func buildBatteryCard() {
        let (card, inner) = makeSectionCard(title: "BATTERY SIMULATION",
                                            accent: UIColor.Phantom.vibrantGreen,
                                            symbol: "battery.75")
        let headerRow = UIStackView(); headerRow.axis = .horizontal
        let levelTitle = UILabel()
        levelTitle.text = "BATTERY LEVEL"
        levelTitle.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        levelTitle.textColor = UIColor.white.withAlphaComponent(0.38)

        batteryValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        batteryValueLabel.textColor = UIColor.Phantom.vibrantGreen

        headerRow.addArrangedSubview(levelTitle)
        headerRow.addArrangedSubview(UIView()) // spacer
        headerRow.addArrangedSubview(batteryValueLabel)

        let level = max(0, PhantomEnvironmentMonitor.shared.batteryLevel)
        batteryValueLabel.text       = "\(Int(level * 100))%"
        batterySlider.value          = level
        batterySlider.minimumTrackTintColor = UIColor.Phantom.vibrantGreen
        batterySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.1)
        batterySlider.thumbTintColor        = UIColor.Phantom.vibrantGreen
        batterySlider.addTarget(self, action: #selector(batterySliderChanged(_:)), for: .valueChanged)

        let note = makeNote("⚠  Battery level on Simulator is always -1 (unknown). Test on physical device.")
        [headerRow, batterySlider, note].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Font Scale Card

    private func buildFontScaleCard() {
        let (card, inner) = makeSectionCard(title: "DYNAMIC TYPE SCALE",
                                            accent: UIColor.Phantom.electricIndigo,
                                            symbol: "textformat.size")
        let grid = UIStackView(); grid.axis = .horizontal; grid.distribution = .fillEqually; grid.spacing = 8
        fontScaleButtons = []
        let currentScale = PhantomLocaleManager.shared.currentFontScale
        for (idx, scale) in fontScaleValues.enumerated() {
            let isActive = abs(currentScale - scale) < 0.01
            let btn = makePill(title: fontScaleNames[idx], active: isActive, color: UIColor.Phantom.electricIndigo)
            btn.tag = idx
            btn.addTarget(self, action: #selector(fontScaleTapped(_:)), for: .touchUpInside)
            fontScaleButtons.append(btn); grid.addArrangedSubview(btn)
        }

        let bodySize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let preview  = UILabel()
        preview.text          = "Body: \(Int(bodySize))pt  ×  scale \(currentScale)"
        preview.font          = UIFont.systemFont(ofSize: 10)
        preview.textColor     = UIColor.white.withAlphaComponent(0.28)
        preview.textAlignment = .right

        [grid, preview].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - UI Style Card

    private func buildUIStyleCard() {
        let (card, inner) = makeSectionCard(title: "INTERFACE STYLE OVERRIDE",
                                            accent: UIColor.Phantom.vibrantPurple,
                                            symbol: "circle.lefthalf.filled")
        let ctrl = UISegmentedControl(items: ["System", "Light", "Dark"])
        styleSegmented(ctrl, accent: UIColor.Phantom.vibrantPurple)
        ctrl.selectedSegmentIndex = 0
        if #available(iOS 13.0, *) {
            switch UIApplication.shared.windows.first?.overrideUserInterfaceStyle ?? .unspecified {
            case .light: ctrl.selectedSegmentIndex = 1
            case .dark:  ctrl.selectedSegmentIndex = 2
            default:     ctrl.selectedSegmentIndex = 0
            }
        }
        ctrl.addTarget(self, action: #selector(uiStyleChanged(_:)), for: .valueChanged)
        let note = makeNote("⚠  Applies to all app windows. Requires iOS 13+.")
        [ctrl, note].forEach { inner.addArrangedSubview($0) }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Data Loading

    @objc private func loadHeaderData() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let device   = UIDevice.current
            let monitor  = PhantomEnvironmentMonitor.shared
            let freeDisk = ByteCountFormatter.string(fromByteCount: monitor.freeDiskSpace,  countStyle: .binary)
            let totDisk  = ByteCountFormatter.string(fromByteCount: monitor.totalDiskSpace, countStyle: .binary)
            let usedMem  = monitor.usedMemory / 1024 / 1024
            let w = Int(UIScreen.main.bounds.width), h = Int(UIScreen.main.bounds.height)
            let scale = Int(UIScreen.main.scale)
            self.modelLabel.text = "MODEL : \(device.modelName)"
            self.osLabel.text    = "KRNL  : iOS \(device.systemVersion)"
            self.diskLabel.text  = "DISK  : \(freeDisk) FREE  /  \(totDisk) TOTAL"
            self.memLabel.text   = "MEM   : \(usedMem) MB IN USE"
            self.resLabel.text   = "RES   : \(w)×\(h)  @\(scale)x"
        }
    }

    @objc private func onSystemStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let level = max(0, PhantomEnvironmentMonitor.shared.batteryLevel)
            self.batteryValueLabel.text = "\(Int(level * 100))%"
            self.batterySlider.value    = level
            self.updateBatteryColor(level: level)
        }
    }

    @objc private func onLocationChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateLocationRows() }
    }

    private func updateLocationRows() {
        let selected  = PhantomLocationManager.shared.selectedLocation
        let locations = PhantomLocationManager.shared.mockLocations
        for (idx, row) in locationRows.enumerated() {
            guard idx < locations.count else { continue }
            let isActive = selected == locations[idx]
            UIView.animate(withDuration: 0.2) {
                row.backgroundColor  = isActive
                    ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.12)
                    : UIColor.white.withAlphaComponent(0.04)
                row.layer.borderColor = isActive
                    ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.4).cgColor
                    : UIColor.white.withAlphaComponent(0.06).cgColor
            }
        }
    }

    // MARK: - Actions

    @objc private func languageTapped(_ sender: UIButton) {
        guard sender.tag < langCodes.count else { return }
        let code = langCodes[sender.tag]
        PhantomLocaleManager.shared.setLanguage(code)
        for (c, btn) in langButtons {
            let active = c == code
            UIView.animate(withDuration: 0.15) {
                btn.backgroundColor = active
                    ? UIColor.Phantom.vibrantPurple : UIColor.white.withAlphaComponent(0.07)
            }
        }
    }

    @objc private func locationTapped(_ sender: UIButton) {
        let locations = PhantomLocationManager.shared.mockLocations
        guard sender.tag < locations.count else { return }
        PhantomLocationManager.shared.selectLocation(locations[sender.tag])
    }

    @objc private func resetLocation() {
        PhantomLocationManager.shared.selectLocation(nil)
    }

    @objc private func thermalChanged(_ sender: UISegmentedControl) {
        let state: ProcessInfo.ThermalState
        switch sender.selectedSegmentIndex {
        case 0: state = .nominal; case 1: state = .fair
        case 2: state = .serious; case 3: state = .critical
        default: state = .nominal
        }
        PhantomEnvironmentMonitor.shared.setSimulatedThermalState(state)
    }

    @objc private func batterySliderChanged(_ sender: UISlider) {
        PhantomEnvironmentMonitor.shared.setSimulatedBatteryLevel(sender.value)
        batteryValueLabel.text = "\(Int(sender.value * 100))%"
        updateBatteryColor(level: sender.value)
    }

    private func updateBatteryColor(level: Float) {
        let color: UIColor = level < 0.2 ? UIColor.Phantom.vibrantRed
                           : level < 0.5 ? UIColor.Phantom.vibrantOrange
                           : UIColor.Phantom.vibrantGreen
        batteryValueLabel.textColor         = color
        batterySlider.minimumTrackTintColor = color
        batterySlider.thumbTintColor        = color
    }

    @objc private func fontScaleTapped(_ sender: UIButton) {
        guard sender.tag < fontScaleValues.count else { return }
        PhantomLocaleManager.shared.setFontScale(fontScaleValues[sender.tag])
        for (idx, btn) in fontScaleButtons.enumerated() {
            let active = idx == sender.tag
            UIView.animate(withDuration: 0.15) {
                btn.backgroundColor = active
                    ? UIColor.Phantom.electricIndigo : UIColor.white.withAlphaComponent(0.07)
            }
        }
    }

    @objc private func uiStyleChanged(_ sender: UISegmentedControl) {
        if #available(iOS 13.0, *) {
            let style: UIUserInterfaceStyle = sender.selectedSegmentIndex == 1 ? .light
                                            : sender.selectedSegmentIndex == 2 ? .dark : .unspecified
            UIApplication.shared.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }

    // MARK: - Factory Helpers

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor    = PhantomTheme.shared.surfaceColor
        v.layer.cornerRadius = 16
        v.layer.borderWidth  = 1
        v.layer.borderColor  = UIColor.white.withAlphaComponent(0.07).cgColor
        return v
    }

    /// Returns (card container, inner content UIStackView below the section header).
    private func makeSectionCard(title: String, accent: UIColor, symbol: String) -> (UIView, UIStackView) {
        let card  = makeCard()

        // 3px left accent strip
        let strip = UIView()
        strip.backgroundColor   = accent
        strip.layer.cornerRadius = 1.5
        strip.translatesAutoresizingMaskIntoConstraints = false

        // 36x36 icon pill
        let iconPill = UIView()
        iconPill.backgroundColor   = accent.withAlphaComponent(0.18)
        iconPill.layer.cornerRadius = 9
        iconPill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconPill.widthAnchor.constraint(equalToConstant: 36),
            iconPill.heightAnchor.constraint(equalToConstant: 36),
        ])

        if #available(iOS 13.0, *) {
            let img = UIImageView(image: UIImage(systemName: symbol))
            img.tintColor = accent; img.contentMode = .scaleAspectFit
            img.translatesAutoresizingMaskIntoConstraints = false
            iconPill.addSubview(img)
            NSLayoutConstraint.activate([
                img.centerXAnchor.constraint(equalTo: iconPill.centerXAnchor),
                img.centerYAnchor.constraint(equalTo: iconPill.centerYAnchor),
                img.widthAnchor.constraint(equalToConstant: 18),
                img.heightAnchor.constraint(equalToConstant: 18),
            ])
        }

        let titleLbl = UILabel()
        titleLbl.text = title; titleLbl.font = UIFont.systemFont(ofSize: 10, weight: .black)
        titleLbl.textColor = UIColor.white.withAlphaComponent(0.85)

        let headerRow = UIStackView(arrangedSubviews: [iconPill, titleLbl])
        headerRow.axis = .horizontal; headerRow.spacing = 10; headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView()
        inner.axis = .vertical; inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false

        [strip, headerRow, divider, inner].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            strip.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            strip.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            strip.widthAnchor.constraint(equalToConstant: 3),

            headerRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            headerRow.leadingAnchor.constraint(equalTo: strip.trailingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: strip.trailingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 1),

            inner.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            inner.leadingAnchor.constraint(equalTo: strip.trailingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return (card, inner)
    }

    private func makePill(title: String, active: Bool, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font  = UIFont.systemFont(ofSize: 13, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor   = active ? color : UIColor.white.withAlphaComponent(0.07)
        btn.layer.cornerRadius = 8
        btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return btn
    }

    private func makeNote(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text; lbl.numberOfLines = 0
        lbl.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.28)
        return lbl
    }

    private func styleSegmented(_ ctrl: UISegmentedControl, accent: UIColor) {
        if #available(iOS 13.0, *) {
            ctrl.selectedSegmentTintColor = accent
            ctrl.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            ctrl.setTitleTextAttributes(
                [.foregroundColor: UIColor.white.withAlphaComponent(0.55),
                 .font: UIFont.systemFont(ofSize: 12, weight: .medium)], for: .normal)
            ctrl.setTitleTextAttributes(
                [.foregroundColor: UIColor.white,
                 .font: UIFont.systemFont(ofSize: 12, weight: .bold)], for: .selected)
        } else {
            ctrl.tintColor = accent
        }
    }
}

// MARK: - UIDevice Model Name

extension UIDevice {
    fileprivate var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { id, elem in
            guard let v = elem.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
        let map: [String: String] = [
            "iPhone10,3": "iPhone X",         "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",        "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",    "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11",        "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max","iPhone12,8": "iPhone SE (2nd gen)",
            "iPhone13,1": "iPhone 12 mini",   "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",    "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,4": "iPhone 13 mini",   "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",    "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",        "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",    "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",        "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",    "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16",        "iPhone17,2": "iPhone 16 Plus",
            "iPhone17,3": "iPhone 16 Pro",    "iPhone17,4": "iPhone 16 Pro Max",
            "i386": "Simulator (x86_64)",     "x86_64": "Simulator (x86_64)",
            "arm64": "Simulator (arm64)",
        ]
        return map[identifier] ?? identifier
    }
}
#endif
