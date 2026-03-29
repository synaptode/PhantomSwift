#if DEBUG
import UIKit

// MARK: - Animation Entry Model

private struct AnimEntry {
    let layerName: String
    let depth: Int
    let key: String
    let animClassName: String
    let duration: TimeInterval
    let repeatCount: Float
    let fillMode: String
    let isBasic: Bool
    let keyPath: String?
}

// MARK: - AnimationInspectorVC

/// Lists all active CAAnimations on the target view's layer tree.
/// Includes a real-time speed slider (0x – 2x) to pause, slow, or accelerate animations for debugging.
internal final class AnimationInspectorVC: UIViewController {

    private let targetView: UIView
    private var entries: [AnimEntry] = []
    private var originalSpeed: Float = 1.0

    private let tableView   = UITableView(frame: .zero, style: .plain)
    private let controlPanel = UIView()
    private let speedSlider  = UISlider()
    private let speedLabel   = UILabel()
    private let pauseButton  = UIButton(type: .system)
    private let resetButton  = UIButton(type: .system)

    private var isPaused = false

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Animations"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        applyNavBarStyle()
        originalSpeed = targetView.layer.speed
        refresh()
        setupControlPanel()
        setupTableView()
        setupNavItems()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore original speed when user leaves
        guard isMovingFromParent || isBeingDismissed else { return }
        targetView.layer.speed = originalSpeed
        if targetView.layer.timeOffset != 0 {
            let pausedAt = targetView.layer.timeOffset
            targetView.layer.timeOffset = 0
            let timeSinceFreeze = targetView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
            targetView.layer.beginTime = targetView.layer.beginTime + timeSinceFreeze
        }
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
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain, target: self, action: #selector(refreshList))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Refresh", style: .plain, target: self, action: #selector(refreshList))
        }
    }

    // MARK: - Data

    private func refresh() {
        entries.removeAll()
        scanLayer(targetView.layer, depth: 0)
    }

    private func scanLayer(_ layer: CALayer, depth: Int) {
        if let keys = layer.animationKeys(), !keys.isEmpty {
            let layerName: String
            if let n = layer.name, !n.isEmpty {
                layerName = n
            } else {
                layerName = String(describing: type(of: layer))
            }

            for key in keys.sorted() {
                guard let anim = layer.animation(forKey: key) else { continue }
                let keyPath: String?
                let isBasic: Bool
                if let basic = anim as? CABasicAnimation {
                    keyPath = basic.keyPath
                    isBasic = true
                } else if let kf = anim as? CAKeyframeAnimation {
                    keyPath = kf.keyPath
                    isBasic = false
                } else {
                    keyPath = nil
                    isBasic = false
                }

                entries.append(AnimEntry(
                    layerName: layerName,
                    depth: depth,
                    key: key,
                    animClassName: String(describing: type(of: anim)),
                    duration: anim.duration,
                    repeatCount: anim.repeatCount,
                    fillMode: anim.fillMode.rawValue,
                    isBasic: isBasic,
                    keyPath: keyPath))
            }
        }
        layer.sublayers?.forEach { scanLayer($0, depth: depth + 1) }
    }

    // MARK: - Control Panel

    private func setupControlPanel() {
        controlPanel.backgroundColor = PhantomTheme.shared.surfaceColor
        controlPanel.layer.borderWidth  = 1
        controlPanel.layer.borderColor  = UIColor.white.withAlphaComponent(0.08).cgColor
        controlPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlPanel)

        // Speed label
        speedLabel.text    = "1.00x"
        speedLabel.font    = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .black)
        speedLabel.textColor = UIColor.Phantom.neonAzure
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(speedLabel)

        let speedHint = UILabel()
        speedHint.text = "ANIMATION SPEED"
        speedHint.font = .systemFont(ofSize: 9, weight: .black)
        speedHint.textColor = UIColor.white.withAlphaComponent(0.3)
        speedHint.textAlignment = .center
        speedHint.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(speedHint)

        // Slider
        speedSlider.minimumValue = 0
        speedSlider.maximumValue = 2
        speedSlider.value        = 1
        speedSlider.minimumTrackTintColor = UIColor.Phantom.neonAzure
        speedSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15)
        speedSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        speedSlider.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(speedSlider)

        let minLbl = UILabel()
        minLbl.text = "0x"
        minLbl.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        minLbl.textColor = UIColor.white.withAlphaComponent(0.4)
        minLbl.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(minLbl)

        let maxLbl = UILabel()
        maxLbl.text = "2x"
        maxLbl.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        maxLbl.textColor = UIColor.white.withAlphaComponent(0.4)
        maxLbl.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(maxLbl)

        // Pause / Resume
        styleControlBtn(pauseButton, title: "⏸  Pause", color: UIColor.Phantom.vibrantOrange)
        pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(pauseButton)

        // Reset speed
        styleControlBtn(resetButton, title: "↺ Reset 1x", color: UIColor.Phantom.vibrantGreen)
        resetButton.addTarget(self, action: #selector(resetSpeed), for: .touchUpInside)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(resetButton)

        let btnStack = UIStackView(arrangedSubviews: [pauseButton, resetButton])
        btnStack.axis = .horizontal
        btnStack.spacing = 10
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(btnStack)

        NSLayoutConstraint.activate([
            controlPanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            speedHint.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 14),
            speedHint.centerXAnchor.constraint(equalTo: controlPanel.centerXAnchor),

            speedLabel.topAnchor.constraint(equalTo: speedHint.bottomAnchor, constant: 4),
            speedLabel.centerXAnchor.constraint(equalTo: controlPanel.centerXAnchor),

            minLbl.centerYAnchor.constraint(equalTo: speedSlider.centerYAnchor),
            minLbl.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 20),

            speedSlider.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 12),
            speedSlider.leadingAnchor.constraint(equalTo: minLbl.trailingAnchor, constant: 8),
            speedSlider.trailingAnchor.constraint(equalTo: maxLbl.leadingAnchor, constant: -8),

            maxLbl.centerYAnchor.constraint(equalTo: speedSlider.centerYAnchor),
            maxLbl.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -20),

            btnStack.topAnchor.constraint(equalTo: speedSlider.bottomAnchor, constant: 12),
            btnStack.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 20),
            btnStack.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -20),
            btnStack.heightAnchor.constraint(equalToConstant: 38),
            btnStack.bottomAnchor.constraint(equalTo: controlPanel.bottomAnchor, constant: -16)
        ])
    }

    private func styleControlBtn(_ btn: UIButton, title: String, color: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        btn.tintColor = color
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth  = 1
        btn.layer.borderColor  = color.withAlphaComponent(0.3).cgColor
    }

    // MARK: - Table

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.06)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(AnimEntryCell.self, forCellReuseIdentifier: "AnimEntryCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: controlPanel.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if entries.isEmpty {
            let lbl = UILabel()
            lbl.text = "No active animations\nfound on this view's layer tree."
            lbl.numberOfLines = 0
            lbl.textAlignment = .center
            lbl.textColor = UIColor.white.withAlphaComponent(0.3)
            lbl.font = .systemFont(ofSize: 14, weight: .medium)
            tableView.backgroundView = lbl
        }
    }

    // MARK: - Actions

    @objc private func handleDone() { dismiss(animated: true) }

    @objc private func refreshList() {
        refresh()
        tableView.reloadData()
        tableView.backgroundView = entries.isEmpty ? makeEmptyLabel() : nil
    }

    private func makeEmptyLabel() -> UILabel {
        let lbl = UILabel()
        lbl.text = "No active animations\nfound on this view's layer tree."
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.textColor = UIColor.white.withAlphaComponent(0.3)
        lbl.font = .systemFont(ofSize: 14, weight: .medium)
        return lbl
    }

    @objc private func sliderChanged() {
        isPaused = false
        let speed = speedSlider.value
        speedLabel.text = String(format: "%.2fx", speed)
        pauseButton.setTitle("⏸  Pause", for: .normal)

        // If was paused, resume first
        if targetView.layer.speed == 0 {
            let pausedAt = targetView.layer.timeOffset
            targetView.layer.timeOffset = 0
            targetView.layer.beginTime  = targetView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        }
        targetView.layer.speed = speed
    }

    @objc private func togglePause() {
        if isPaused {
            // Resume
            isPaused = false
            let pausedAt = targetView.layer.timeOffset
            targetView.layer.timeOffset = 0
            let currentTime = CACurrentMediaTime()
            let timeSinceFreeze = targetView.layer.convertTime(currentTime, from: nil) - pausedAt
            targetView.layer.beginTime = targetView.layer.beginTime + timeSinceFreeze
            targetView.layer.speed = speedSlider.value
            pauseButton.setTitle("⏸  Pause", for: .normal)
            pauseButton.setTitleColor(UIColor.Phantom.vibrantOrange, for: .normal)
        } else {
            // Pause
            isPaused = true
            let pauseTime = targetView.layer.convertTime(CACurrentMediaTime(), from: nil)
            targetView.layer.speed       = 0
            targetView.layer.timeOffset  = pauseTime
            pauseButton.setTitle("▶  Resume", for: .normal)
            pauseButton.setTitleColor(UIColor.Phantom.vibrantGreen, for: .normal)
        }
    }

    @objc private func resetSpeed() {
        isPaused = false
        if targetView.layer.speed == 0 {
            let pausedAt = targetView.layer.timeOffset
            targetView.layer.timeOffset = 0
            let timeSinceFreeze = targetView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
            targetView.layer.beginTime  = targetView.layer.beginTime + timeSinceFreeze
        }
        targetView.layer.speed = 1.0
        speedSlider.value = 1.0
        speedLabel.text = "1.00x"
        pauseButton.setTitle("⏸  Pause", for: .normal)
        pauseButton.setTitleColor(UIColor.Phantom.vibrantOrange, for: .normal)
    }
}

// MARK: - UITableViewDataSource, Delegate

extension AnimationInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "AnimEntryCell", for: indexPath) as! AnimEntryCell
        cell.configure(with: entries[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 86 }
}

// MARK: - AnimEntryCell

private final class AnimEntryCell: UITableViewCell {

    private let typeBadge    = UILabel()
    private let keyLabel     = UILabel()
    private let keyPathLabel = UILabel()
    private let detailLabel  = UILabel()
    private let layerLabel   = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        typeBadge.font = .systemFont(ofSize: 9, weight: .black)
        typeBadge.layer.cornerRadius = 6
        typeBadge.layer.masksToBounds = true
        typeBadge.textAlignment = .center
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeBadge)

        keyLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        keyLabel.textColor = .white
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        keyPathLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        keyPathLabel.textColor = UIColor.Phantom.neonAzure
        keyPathLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyPathLabel)

        detailLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        detailLabel.numberOfLines = 1
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailLabel)

        layerLabel.font = .systemFont(ofSize: 9, weight: .medium)
        layerLabel.textColor = UIColor.Phantom.vibrantPurple
        layerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(layerLabel)

        NSLayoutConstraint.activate([
            typeBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            typeBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            typeBadge.heightAnchor.constraint(equalToConstant: 20),

            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyLabel.trailingAnchor.constraint(equalTo: typeBadge.leadingAnchor, constant: -8),

            keyPathLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 3),
            keyPathLabel.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            keyPathLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: keyPathLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            layerLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 4),
            layerLabel.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            layerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: AnimEntry) {
        keyLabel.text = entry.key

        let animType = entry.isBasic ? "BASIC" : entry.animClassName.contains("Keyframe") ? "KEYFRAME" : "GROUP"
        let color: UIColor
        switch animType {
        case "BASIC":    color = UIColor.Phantom.vibrantGreen
        case "KEYFRAME": color = UIColor.Phantom.vibrantOrange
        default:         color = UIColor.Phantom.vibrantPurple
        }
        typeBadge.text = "  \(animType)  "
        typeBadge.textColor = color
        typeBadge.backgroundColor = color.withAlphaComponent(0.12)

        if let kp = entry.keyPath, !kp.isEmpty {
            keyPathLabel.text = "keyPath: \(kp)"
            keyPathLabel.isHidden = false
        } else {
            keyPathLabel.isHidden = true
        }

        let dur     = String(format: "%.2fs", entry.duration)
        let repeat_ = entry.repeatCount == 0 ? "∞" : String(Int(entry.repeatCount)) + "×"
        detailLabel.text = "duration: \(dur)  repeat: \(repeat_)  fill: \(entry.fillMode)"

        let indent = String(repeating: "  ", count: entry.depth)
        layerLabel.text = "\(indent)↑ \(entry.layerName)"
    }
}

#endif
