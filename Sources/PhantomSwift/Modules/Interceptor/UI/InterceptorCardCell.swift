#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// A high-fidelity, modern card for displaying interception rules with glassmorphism.
internal final class InterceptorCardCell: UICollectionViewCell {
    private let containerView = UIView()
    private let glowView = UIView()
    private let iconContainer = UIView()
    private let iconLabel = UILabel()
    private let statePill = UILabel()
    private let typePill = UILabel()
    private let methodPill = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
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

        glowView.layer.cornerRadius = 24
        glowView.alpha = 0.12
        contentView.addSubview(glowView)

        containerView.backgroundColor = PhantomTheme.shared.surfaceColor
        containerView.layer.cornerRadius = 24
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        contentView.addSubview(containerView)
        
        iconContainer.layer.cornerRadius = 14
        iconContainer.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        containerView.addSubview(iconContainer)
        
        iconLabel.font = .systemFont(ofSize: 18)
        iconContainer.addSubview(iconLabel)

        [statePill, typePill, methodPill].forEach {
            $0.font = .systemFont(ofSize: 10, weight: .bold)
            $0.textAlignment = .center
            $0.layer.cornerRadius = 9
            $0.clipsToBounds = true
            containerView.addSubview($0)
        }
        statePill.font = .systemFont(ofSize: 10, weight: .black)
        statePill.layer.cornerRadius = 10
        methodPill.isHidden = true
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        containerView.addSubview(subtitleLabel)

        detailLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        detailLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.72)
        detailLabel.numberOfLines = 2
        containerView.addSubview(detailLabel)
        
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

        [glowView, containerView, iconContainer, iconLabel, statePill, typePill, methodPill, titleLabel, subtitleLabel, detailLabel, statusToggle, hitBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            glowView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            glowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            glowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            glowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

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

            statePill.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            statePill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            statePill.heightAnchor.constraint(equalToConstant: 20),
            statePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 62),

            typePill.leadingAnchor.constraint(equalTo: statePill.trailingAnchor, constant: 8),
            typePill.centerYAnchor.constraint(equalTo: statePill.centerYAnchor),
            typePill.heightAnchor.constraint(equalToConstant: 18),
            typePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),

            methodPill.leadingAnchor.constraint(equalTo: typePill.trailingAnchor, constant: 8),
            methodPill.centerYAnchor.constraint(equalTo: typePill.centerYAnchor),
            methodPill.heightAnchor.constraint(equalToConstant: 18),
            methodPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 46),
            
            titleLabel.topAnchor.constraint(equalTo: statePill.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -12),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            detailLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),

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
        subtitleLabel.text = rule.typeDisplayName.uppercased()
        detailLabel.text = rule.detailDisplayName
        statusToggle.isOn = phantomRule.isEnabled

        typePill.text = "  \(rule.typeDisplayName.uppercased())  "
        methodPill.text = rule.methodDisplayName.map { "  \($0.uppercased())  " }
        methodPill.isHidden = rule.methodDisplayName == nil
        statePill.text = phantomRule.isEnabled ? " ACTIVE " : " PAUSED "

        var accentColor = PhantomTheme.shared.primaryColor
        switch rule {
        case .block:
            iconLabel.text = "🚫"
            accentColor = UIColor.Phantom.vibrantRed
        case .delay:
            iconLabel.text = "⏳"
            accentColor = UIColor.Phantom.vibrantOrange
        case .mockResponse:
            iconLabel.text = "🎭"
            accentColor = UIColor.Phantom.vibrantPurple
        case .redirect:
            iconLabel.text = "🔀"
            accentColor = UIColor.Phantom.neonAzure
        case .modifyRequest:
            iconLabel.text = "🛠️"
            accentColor = UIColor.Phantom.vibrantTeal
        case .mapLocal:
            iconLabel.text = "📂"
            accentColor = UIColor.Phantom.vibrantBrown
        }

        glowView.backgroundColor = accentColor
        iconContainer.backgroundColor = accentColor.withAlphaComponent(0.14)
        typePill.textColor = accentColor
        typePill.backgroundColor = accentColor.withAlphaComponent(0.12)
        methodPill.textColor = UIColor.white.withAlphaComponent(0.82)
        methodPill.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        statePill.textColor = phantomRule.isEnabled ? UIColor.Phantom.vibrantGreen : UIColor.white.withAlphaComponent(0.7)
        statePill.backgroundColor = phantomRule.isEnabled
            ? UIColor.Phantom.vibrantGreen.withAlphaComponent(0.12)
            : UIColor.white.withAlphaComponent(0.08)
        hitBadge.textColor = accentColor
        hitBadge.backgroundColor = accentColor.withAlphaComponent(0.12)
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
