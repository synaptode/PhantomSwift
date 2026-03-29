#if DEBUG
import UIKit

/// A reusable empty state view with an illustration and description.
internal final class PhantomEmptyStateView: UIView {
    private let stackView = UIStackView()
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
    internal init(emoji: String, title: String, message: String) {
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
        stackView.spacing = 10
        addSubview(stackView)
        
        emojiLabel.font = UIFont.systemFont(ofSize: 64)
        stackView.addArrangedSubview(emojiLabel)
        
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        stackView.addArrangedSubview(titleLabel)
        
        messageLabel.font = UIFont.systemFont(ofSize: 14)
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
