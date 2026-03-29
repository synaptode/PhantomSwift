#if DEBUG
import UIKit

/// A modern, glassmorphic grid cell for the asset auditor.
internal final class AssetGridCell: UICollectionViewCell {
    private let previewContainer = UIView()
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private let infoLabel = UILabel()
    private let heavyBadge = UIView()
    private let heavyText = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        PhantomTheme.shared.applyCardStyle(to: contentView)
        
        previewContainer.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        previewContainer.clipsToBounds = true
        previewContainer.layer.cornerRadius = 12
        if #available(iOS 13.0, *) { previewContainer.layer.cornerCurve = .continuous }
        contentView.addSubview(previewContainer)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        previewContainer.addSubview(imageView)
        
        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = PhantomTheme.shared.textColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(nameLabel)
        
        infoLabel.font = .systemFont(ofSize: 10)
        infoLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        contentView.addSubview(infoLabel)
        
        heavyBadge.backgroundColor = .systemRed.withAlphaComponent(0.9)
        heavyBadge.layer.cornerRadius = 6
        heavyBadge.isHidden = true
        contentView.addSubview(heavyBadge)
        
        heavyText.text = "HEAVY"
        heavyText.font = .systemFont(ofSize: 8, weight: .black)
        heavyText.textColor = .white
        heavyBadge.addSubview(heavyText)
        
        [previewContainer, imageView, nameLabel, infoLabel, heavyBadge, heavyText].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            previewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            previewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            previewContainer.heightAnchor.constraint(equalToConstant: 100),
            
            imageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            
            heavyBadge.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            heavyBadge.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            heavyBadge.heightAnchor.constraint(equalToConstant: 18),
            
            heavyText.leadingAnchor.constraint(equalTo: heavyBadge.leadingAnchor, constant: 6),
            heavyText.trailingAnchor.constraint(equalTo: heavyBadge.trailingAnchor, constant: -6),
            heavyText.centerYAnchor.constraint(equalTo: heavyBadge.centerYAnchor)
        ])
    }
    
    func configure(with asset: PhantomAssetInfo) {
        nameLabel.text = asset.name
        let sizeStr = ByteCountFormatter.string(fromByteCount: asset.size, countStyle: .file)
        infoLabel.text = "\(sizeStr) • \(asset.resolution)"
        
        let isHeavy = asset.size > 300_000 // > 300KB
        heavyBadge.isHidden = !isHeavy
        
        if let cachedImage = asset.image {
            imageView.image = cachedImage
            imageView.alpha = 1.0
        } else if asset.type == .image {
            imageView.image = UIImage(contentsOfFile: asset.path)
            imageView.alpha = 1.0
        } else {
            if #available(iOS 13.0, *) {
                let iconName: String
                switch asset.type {
                case .config: iconName = "doc.text.fill"
                case .font: iconName = "textformat"
                default: iconName = "doc.fill"
                }
                imageView.image = UIImage(systemName: iconName)
            }
            imageView.contentMode = .center
            imageView.tintColor = PhantomTheme.shared.textColor.withAlphaComponent(0.2)
            imageView.alpha = 0.5
        }
        
        // Add Source Indicator
        setupSourceIndicator(for: asset.source)
    }
    
    private let sourceIndicator = UILabel()
    private func setupSourceIndicator(for source: PhantomAssetInfo.SourceType) {
        if sourceIndicator.superview == nil {
            sourceIndicator.font = .systemFont(ofSize: 8, weight: .black)
            sourceIndicator.textColor = .white
            sourceIndicator.layer.cornerRadius = 4
            sourceIndicator.clipsToBounds = true
            sourceIndicator.textAlignment = .center
            contentView.addSubview(sourceIndicator)
            sourceIndicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                sourceIndicator.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -8),
                sourceIndicator.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
                sourceIndicator.heightAnchor.constraint(equalToConstant: 14),
                sourceIndicator.widthAnchor.constraint(equalToConstant: 45)
            ])
        }
        
        sourceIndicator.text = source.rawValue
        sourceIndicator.backgroundColor = source == .bundle ? .systemBlue.withAlphaComponent(0.8) : .systemPurple.withAlphaComponent(0.8)
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
