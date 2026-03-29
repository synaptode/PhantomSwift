#if DEBUG
import UIKit

/// A reusable notification badge view.
internal final class PhantomBadgeView: UIView {
    private let label = UILabel()
    
    internal var text: String? {
        get { return label.text }
        set { 
            label.text = newValue
            self.isHidden = (newValue == nil || newValue?.isEmpty == true)
        }
    }
    
    internal override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        self.backgroundColor = UIColor.Phantom.error
        self.layer.cornerRadius = 9
        self.clipsToBounds = true
        
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            label.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
    
    /// Starts a subtle pulsing animation.
    internal func startPulsing() {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.15
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        self.layer.add(animation, forKey: "pulsing")
    }
}
#endif
