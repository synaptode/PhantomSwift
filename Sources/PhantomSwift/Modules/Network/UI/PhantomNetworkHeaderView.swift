#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// A premium header view for displaying network request summaries.
internal final class PhantomNetworkHeaderView: UIView {
    private let containerView = UIView()
    private let methodLabel = UILabel()
    private let statusLabel = UILabel()
    private let urlLabel = UILabel()
    private let infoStack = UIStackView()
    
    private let durationLabel = UILabel()
    private let sizeLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        containerView.backgroundColor = PhantomTheme.shared.surfaceColor
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        methodLabel.font = UIFont.systemFont(ofSize: 12, weight: .black)
        methodLabel.textColor = .white
        methodLabel.layer.cornerRadius = 6
        methodLabel.clipsToBounds = true
        methodLabel.textAlignment = .center
        methodLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(methodLabel)
        
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .black)
        statusLabel.textColor = .white
        statusLabel.layer.cornerRadius = 6
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        urlLabel.font = UIFont.phantomMonospaced(size: 11, weight: .medium)
        urlLabel.textColor = PhantomTheme.shared.textColor
        urlLabel.numberOfLines = 2
        urlLabel.lineBreakMode = .byCharWrapping
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(urlLabel)
        
        infoStack.axis = .horizontal
        infoStack.spacing = 15
        infoStack.distribution = .fillProportionally
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(infoStack)
        
        [durationLabel, sizeLabel].forEach {
            $0.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            $0.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
            $0.textAlignment = .center
            infoStack.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            methodLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            methodLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            methodLabel.widthAnchor.constraint(equalToConstant: 60),
            methodLabel.heightAnchor.constraint(equalToConstant: 24),
            
            statusLabel.topAnchor.constraint(equalTo: methodLabel.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: methodLabel.trailingAnchor, constant: 8),
            statusLabel.widthAnchor.constraint(equalToConstant: 50),
            statusLabel.heightAnchor.constraint(equalToConstant: 24),
            
            urlLabel.topAnchor.constraint(equalTo: methodLabel.bottomAnchor, constant: 12),
            urlLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            urlLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            
            infoStack.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 12),
            infoStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            infoStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
    }
    
    func configure(with request: PhantomRequest) {
        methodLabel.text = request.method.uppercased()
        methodLabel.backgroundColor = color(for: request.method)
        
        urlLabel.text = request.url.absoluteString
        
        if let response = request.response {
            statusLabel.text = "\(response.statusCode)"
            statusLabel.backgroundColor = response.statusCode < 400 ? UIColor.Phantom.success : UIColor.Phantom.error
            statusLabel.isHidden = false
            
            durationLabel.text = String(format: "%.3f s", response.duration)
            let size = ByteCountFormatter.string(fromByteCount: Int64(response.body?.count ?? 0), countStyle: .file)
            sizeLabel.text = size
            infoStack.isHidden = false
        } else {
            statusLabel.isHidden = true
            infoStack.isHidden = true
        }
    }
    
    private func color(for method: String) -> UIColor {
        switch method.uppercased() {
        case "GET": return UIColor.Phantom.success
        case "POST": return UIColor.Phantom.primary
        case "PUT", "PATCH": return UIColor.Phantom.warning
        case "DELETE": return UIColor.Phantom.error
        default: return PhantomTheme.shared.primaryColor
        }
    }
}
#endif
