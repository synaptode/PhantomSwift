#if DEBUG
import UIKit

extension UILabel {
    /// Sets the letter spacing (kerning) for the label's text.
    var letterSpacing: CGFloat {
        set {
            let text = self.text ?? ""
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.kern, value: newValue, range: NSRange(location: 0, length: text.count))
            self.attributedText = attributedString
        }
        get {
            if let attributedText = attributedText, 
               let value = attributedText.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat {
                return value
            }
            return 0
        }
    }
}

extension UIView {
    /// Applies a linear gradient to the view's layer.
    func applyGradient(colors: [UIColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        
        // Remove existing gradients
        layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// Captures a snapshot image of the view.
    func snapshot() -> UIImage? {
        guard bounds.size.width > 0, bounds.size.height > 0 else { return nil }
        
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { context in
                layer.render(in: context.cgContext)
            }
        } else {
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            layer.render(in: context)
            return UIGraphicsGetImageFromCurrentImageContext()
        }
    }
}

extension UISegmentedControl {
    /// Applies the Phantom design system styling to the segmented control.
    func applyPhantomStyle() {
        if #available(iOS 13.0, *) {
            selectedSegmentTintColor = PhantomTheme.shared.primaryColor
            
            let normalAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: PhantomTheme.shared.textColor.withAlphaComponent(0.7),
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]
            let selectedAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 11, weight: .bold)
            ]
            
            setTitleTextAttributes(normalAttrs, for: .normal)
            setTitleTextAttributes(selectedAttrs, for: .selected)
        } else {
            tintColor = PhantomTheme.shared.primaryColor
        }
    }
}

extension UISearchBar {
    /// Applies the Phantom design system styling to the search bar.
    func applyPhantomStyle() {
        if #available(iOS 13.0, *) {
            searchTextField.backgroundColor = PhantomTheme.shared.surfaceColor
            searchTextField.textColor = PhantomTheme.shared.textColor
            searchTextField.font = .systemFont(ofSize: 14)
            
            // Placeholder color
            if let placeholder = placeholder {
                let placeholderAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: PhantomTheme.shared.textColor.withAlphaComponent(0.4)
                ]
                searchTextField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttrs)
            }
            
            // Glass effect for the search bar itself
            barTintColor = .clear
            backgroundImage = UIImage()
            isTranslucent = true
        } else {
            tintColor = PhantomTheme.shared.primaryColor
        }
    }
}

#endif
