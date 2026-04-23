#if DEBUG
import UIKit

/// A reusable empty state view with an illustration and description.
internal final class PhantomEmptyStateView: UIView {
    internal enum Style {
        case standard
        case compact
    }

    private let stackView = UIStackView()
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let style: Style
    
    internal init(emoji: String, title: String, message: String, style: Style = .standard) {
        self.style = style
        super.init(frame: .zero)
        emojiLabel.text = emoji
        titleLabel.text = title
        messageLabel.text = message
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = style == .compact ? 8 : 10
        addSubview(stackView)

        switch style {
        case .standard:
            emojiLabel.font = UIFont.systemFont(ofSize: 64)
            titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            messageLabel.font = UIFont.systemFont(ofSize: 14)
        case .compact:
            emojiLabel.font = UIFont.systemFont(ofSize: 46)
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
            messageLabel.font = UIFont.systemFont(ofSize: 12)
        }

        stackView.addArrangedSubview(emojiLabel)

        titleLabel.textColor = PhantomTheme.shared.textColor
        stackView.addArrangedSubview(titleLabel)

        messageLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        stackView.addArrangedSubview(messageLabel)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -40)
        ])
    }
}
#endif
