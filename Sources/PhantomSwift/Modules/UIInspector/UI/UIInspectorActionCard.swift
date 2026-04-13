#if DEBUG
import UIKit

/// A floating glass card that appears when a view is selected in the UI Inspector.
/// Shows view type, frame, snapshot preview, and quick actions.
internal final class UIInspectorActionCard: UIView {
    private let backgroundView = UIVisualEffectView(effect: PhantomTheme.shared.glassEffect)
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let previewImage = UIImageView()

    private let flashButton   = UIButton(type: .system)
    private let hideButton    = UIButton(type: .system)
    private let inspectButton = UIButton(type: .system)
    private let treeButton    = UIButton(type: .system)
    private let editButton    = UIButton(type: .system)
    private let measureButton = UIButton(type: .system)

    private var targetView: UIView?
    internal var onInspect:   ((UIView) -> Void)?
    internal var onShowTree:  ((UIView) -> Void)?
    internal var onLiveEdit:  ((UIView) -> Void)?
    internal var onMeasure:   (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        layer.cornerRadius = 22
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor

        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(backgroundView)

        // Preview thumbnail
        previewImage.contentMode = .scaleAspectFit
        previewImage.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        previewImage.layer.cornerRadius = 8
        previewImage.layer.masksToBounds = true
        previewImage.layer.borderWidth = 1
        previewImage.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        previewImage.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .black)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        detailLabel.textColor = UIColor.Phantom.neonAzure
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [previewImage, infoStack])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(topRow)

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(divider)

        configureActionBtn(flashButton,   title: "Flash",   icon: "sparkles",           color: UIColor.Phantom.vibrantOrange)
        configureActionBtn(hideButton,    title: "Hide",    icon: "eye.slash",           color: UIColor.Phantom.vibrantRed)
        configureActionBtn(inspectButton, title: "Detail",  icon: "magnifyingglass",     color: UIColor.Phantom.neonAzure)
        configureActionBtn(treeButton,    title: "Tree",    icon: "rectangle.stack",     color: UIColor.Phantom.vibrantGreen)
        configureActionBtn(editButton,    title: "Edit",    icon: "slider.horizontal.3", color: UIColor.Phantom.electricIndigo)
        configureActionBtn(measureButton, title: "Measure", icon: "ruler",               color: .white)

        flashButton.addTarget(self,   action: #selector(handleFlash),   for: .touchUpInside)
        hideButton.addTarget(self,    action: #selector(handleHide),    for: .touchUpInside)
        inspectButton.addTarget(self, action: #selector(handleInspect), for: .touchUpInside)
        treeButton.addTarget(self,    action: #selector(handleTree),    for: .touchUpInside)
        editButton.addTarget(self,    action: #selector(handleEdit),    for: .touchUpInside)
        measureButton.addTarget(self, action: #selector(handleMeasure), for: .touchUpInside)

        let row1 = UIStackView(arrangedSubviews: [flashButton, hideButton, inspectButton, treeButton])
        row1.axis = .horizontal
        row1.spacing = 6
        row1.distribution = .fillEqually
        row1.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(row1)

        let row2 = UIStackView(arrangedSubviews: [editButton, measureButton])
        row2.axis = .horizontal
        row2.spacing = 6
        row2.distribution = .fillEqually
        row2.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(row2)

        NSLayoutConstraint.activate([
            previewImage.widthAnchor.constraint(equalToConstant: 44),
            previewImage.heightAnchor.constraint(equalToConstant: 44),

            topRow.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 14),
            topRow.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 1),

            row1.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            row1.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            row1.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            row1.heightAnchor.constraint(equalToConstant: 32),

            row2.topAnchor.constraint(equalTo: row1.bottomAnchor, constant: 6),
            row2.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            row2.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            row2.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -14),
            row2.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func configureActionBtn(_ button: UIButton, title: String, icon: String, color: UIColor) {
        if #available(iOS 13.0, *) {
            button.setImage(UIImage.phantomSymbol(icon, config: PhantomSymbolConfig(pointSize: 11, weight: .semibold)), for: .normal)
        }
        button.setTitle(" \(title)", for: .normal)
        button.tintColor = color
        // Explicitly set title color — UIButton(type: .system) may ignore tintColor for text
        button.setTitleColor(color, for: .normal)
        button.setTitleColor(color.withAlphaComponent(0.5), for: .highlighted)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        button.backgroundColor = color.withAlphaComponent(0.15)
        button.layer.cornerRadius = 8
    }

    func show(for view: UIView) {
        self.targetView = view
        titleLabel.text = String(describing: type(of: view)).uppercased()
        detailLabel.text = String(format: "%.0f,%.0f  %dx%d",
                                   view.frame.origin.x, view.frame.origin.y,
                                   Int(view.frame.width), Int(view.frame.height))

        // Snapshot preview
        if view.bounds.width > 0 && view.bounds.height > 0 {
            UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
            if let ctx = UIGraphicsGetCurrentContext() { view.layer.render(in: ctx) }
            previewImage.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        } else {
            previewImage.image = nil
        }

        // Animate in
        self.transform = CGAffineTransform(translationX: 0, y: 80).scaledBy(x: 0.9, y: 0.9)
        self.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.transform = .identity
            self.alpha = 1
        }

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    @objc private func handleFlash() {
        guard let view = targetView else { return }
        let originalColor = view.backgroundColor
        UIView.animate(withDuration: 0.15, animations: {
            view.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.6)
            view.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                view.backgroundColor = originalColor
                view.transform = .identity
            }
        }
    }

    @objc private func handleHide() {
        guard let view = targetView else { return }
        view.isHidden.toggle()
        let title = view.isHidden ? "Show" : "Hide"
        let icon = view.isHidden ? "eye" : "eye.slash"
        hideButton.setTitle(" \(title)", for: .normal)
        if #available(iOS 13.0, *) {
            hideButton.setImage(UIImage.phantomSymbol(icon, config: PhantomSymbolConfig(pointSize: 11, weight: .semibold)), for: .normal)
        }
    }

    @objc private func handleInspect() {
        guard let view = targetView else { return }
        onInspect?(view)
    }

    @objc private func handleTree() {
        guard let view = targetView else { return }
        onShowTree?(view)
    }

    @objc private func handleEdit() {
        guard let view = targetView else { return }
        onLiveEdit?(view)
    }

    @objc private func handleMeasure() {
        onMeasure?()
    }
}
#endif
