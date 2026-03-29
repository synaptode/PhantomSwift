#if DEBUG
import UIKit

extension UIFont {
    internal static func phantomMonospaced(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if #available(iOS 13.0, *) {
            return .monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            let fontName: String
            switch weight {
            case .bold: fontName = "Menlo-Bold"
            case .semibold, .medium: fontName = "Menlo-Bold" // Fallback to bold if medium not found
            default: fontName = "Menlo-Regular"
            }
            return UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
    }
}
#endif
