#if DEBUG
import UIKit

/// A modern, glassmorphic card cell for the storage dashboard.
internal final class StorageDashboardCell: UICollectionViewCell {
    private let iconContainer = UIView()
    private let iconImage = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let arrowImage = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        PhantomTheme.shared.applyCardStyle(to: contentView)
        
        iconContainer.backgroundColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { iconContainer.layer.cornerCurve = .continuous }
        contentView.addSubview(iconContainer)
        
        iconImage.contentMode = .scaleAspectFit
        iconImage.tintColor = PhantomTheme.shared.primaryColor
        iconContainer.addSubview(iconImage)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        contentView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        contentView.addSubview(subtitleLabel)
        
        if #available(iOS 13.0, *) {
            arrowImage.image = UIImage(systemName: "chevron.right")
            arrowImage.preferredSymbolConfiguration = .init(pointSize: 12, weight: .bold)
        }
        arrowImage.tintColor = PhantomTheme.shared.textColor.withAlphaComponent(0.2)
        contentView.addSubview(arrowImage)
        
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImage.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 24),
            iconImage.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            arrowImage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            arrowImage.topAnchor.constraint(equalTo: iconContainer.topAnchor)
        ])
    }
    
    func configure(title: String, subtitle: String, icon: String, iconColor: UIColor) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        if #available(iOS 15.0, *) {
            let config = UIImage.SymbolConfiguration(hierarchicalColor: iconColor)
            iconImage.image = UIImage(systemName: icon, withConfiguration: config)
        } else if #available(iOS 13.0, *) {
            iconImage.image = UIImage(systemName: icon)
        }
        iconContainer.backgroundColor = iconColor.withAlphaComponent(0.12)
        iconImage.tintColor = iconColor
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
                self.contentView.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }
}
#endif
