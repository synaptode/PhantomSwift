#if DEBUG
import UIKit

/// Minimal floating pill trigger — Niagara style.
/// Icon-only with a live pulsing dot; no text label for maximum compactness.
internal final class PhantomDynamicIsland: UIView {
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let iconImageView = UIImageView()
    /// Small pulsing dot indicating PhantomSwift is actively monitoring.
    private let dot = UIView()

    internal var onAction: (() -> Void)?

    private var timer: Timer?
    private var isDotAnimating = false

    internal override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        startUpdating()
        observeNetworkState()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func observeNetworkState() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateForNetworkState), name: PhantomNetworkSimulator.stateChangedNotification, object: nil)
        updateForNetworkState()
    }

    @objc private func updateForNetworkState() {
        let simulator = PhantomNetworkSimulator.shared
        let isWarning = simulator.isEnabled && (simulator.latency > 0 || simulator.errorRate > 0)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let accent = isWarning ? UIColor.Phantom.warning : PhantomTheme.shared.primaryColor
            UIView.animate(withDuration: 0.35) {
                self.iconImageView.tintColor = accent
                self.dot.backgroundColor = accent
                self.backgroundView.layer.borderColor = accent.withAlphaComponent(0.35).cgColor
            }
            if isWarning {
                self.iconImageView.image = UIImage.phantomSymbol("wifi.exclamationmark")
            } else {
                self.iconImageView.image = UIImage.phantomSymbol("bolt.horizontal.circle.fill")
            }
        }
    }

    private func setup() {
        backgroundColor = .clear

        // Blur background — pill shape
        backgroundView.layer.cornerRadius = bounds.height / 2
        backgroundView.clipsToBounds = true
        backgroundView.layer.borderWidth = 1.0
        backgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        addSubview(backgroundView)

        // Icon — centered, single icon is the entire UI
        iconImageView.image = UIImage.phantomSymbol("bolt.horizontal.circle.fill")
        iconImageView.tintColor = PhantomTheme.shared.primaryColor
        iconImageView.contentMode = .scaleAspectFit
        backgroundView.contentView.addSubview(iconImageView)

        // Live dot — small circle bottom-right of icon
        dot.backgroundColor = PhantomTheme.shared.primaryColor
        dot.layer.cornerRadius = 3.5
        dot.clipsToBounds = true
        backgroundView.contentView.addSubview(dot)

        // Layout
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        dot.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor, constant: -4),
            iconImageView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7),
            dot.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 2),
            dot.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.5, options: .allowUserInteraction) {
            self.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { [weak self] _ in
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .allowUserInteraction) {
                self?.transform = .identity
            }
            self?.onAction?()
        }
    }

    private func startUpdating() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pulseDot()
        }
    }

    /// Pulses the live dot once per second — subtle fade to 30% and back.
    private func pulseDot() {
        guard !isDotAnimating else { return }
        isDotAnimating = true
        UIView.animate(withDuration: 0.45) { [weak self] in
            self?.dot.alpha = 0.3
        } completion: { [weak self] _ in
            UIView.animate(withDuration: 0.45) { [weak self] in
                self?.dot.alpha = 1.0
            } completion: { [weak self] _ in
                self?.isDotAnimating = false
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = bounds.height / 2
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
