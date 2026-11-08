#if DEBUG
import UIKit

/// Interactive filter chip button for category/status filtering.
internal final class FilterChip: UIControl {
    let title: String
    private let label = UILabel()

    var isActive: Bool = false {
        didSet { updateAppearance() }
    }

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        if isActive {
            backgroundColor = PhantomTheme.shared.primaryColor
            layer.borderColor = PhantomTheme.shared.primaryColor.cgColor
            label.textColor = .white
        } else {
            backgroundColor = PhantomTheme.shared.surfaceColor
            layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1.0 }
    }
}
#endif
