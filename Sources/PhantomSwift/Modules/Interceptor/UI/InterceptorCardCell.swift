#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// A high-fidelity, modern card for displaying interception rules with glassmorphism.
internal final class InterceptorCardCell: UICollectionViewCell {
    private let containerView = UIView()
    private let iconContainer = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusToggle = UISwitch()
    private let hitBadge = UILabel()
    
    var onToggle: ((Bool) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        containerView.backgroundColor = PhantomTheme.shared.surfaceColor
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        contentView.addSubview(containerView)
        
        iconContainer.layer.cornerRadius = 14
        iconContainer.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        containerView.addSubview(iconContainer)
        
        iconLabel.font = .systemFont(ofSize: 18)
        iconContainer.addSubview(iconLabel)
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        containerView.addSubview(subtitleLabel)
        
        statusToggle.onTintColor = PhantomTheme.shared.primaryColor
        statusToggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        statusToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        containerView.addSubview(statusToggle)

        hitBadge.font = .systemFont(ofSize: 10, weight: .bold)
        hitBadge.textColor = PhantomTheme.shared.primaryColor
        hitBadge.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        hitBadge.layer.cornerRadius = 8
        hitBadge.clipsToBounds = true
        hitBadge.textAlignment = .center
        hitBadge.isHidden = true
        containerView.addSubview(hitBadge)

        [containerView, iconContainer, iconLabel, titleLabel, subtitleLabel, statusToggle, hitBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -12),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            statusToggle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            statusToggle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),

            hitBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            hitBadge.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            hitBadge.heightAnchor.constraint(equalToConstant: 18),
            hitBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
        
        PhantomTheme.shared.applyPremiumShadow(to: containerView.layer)
    }
    
    @objc private func toggleChanged(_ sender: UISwitch) {
        onToggle?(sender.isOn)
    }
    
    func configure(with phantomRule: PhantomInterceptRule) {
        let rule = phantomRule.rule
        titleLabel.text = rule.urlPattern
        subtitleLabel.text = rule.typeDisplayName
        statusToggle.isOn = phantomRule.isEnabled
        
        switch rule {
        case .block:
            iconLabel.text = "🚫"
            iconContainer.backgroundColor = UIColor.Phantom.vibrantRed.withAlphaComponent(0.1)
        case .delay:
            iconLabel.text = "⏳"
            iconContainer.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.1)
        case .mockResponse:
            iconLabel.text = "🎭"
            iconContainer.backgroundColor = UIColor.Phantom.vibrantPurple.withAlphaComponent(0.1)
        case .redirect:
            iconLabel.text = "🔀"
            iconContainer.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.1)
        case .modifyRequest:
            iconLabel.text = "🛠️"
            iconContainer.backgroundColor = UIColor.Phantom.vibrantTeal.withAlphaComponent(0.1)
        case .mapLocal:
            iconLabel.text = "📂"
            iconContainer.backgroundColor = UIColor.Phantom.vibrantBrown.withAlphaComponent(0.1)
        }
        
        containerView.alpha = phantomRule.isEnabled ? 1.0 : 0.6

        if phantomRule.hitCount > 0 {
            hitBadge.text = "  \(phantomRule.hitCount) hits  "
            hitBadge.isHidden = false
        } else {
            hitBadge.isHidden = true
        }
    }
}
#endif
