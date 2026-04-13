#if DEBUG
import UIKit

internal enum PhantomSymbolWeight {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    @available(iOS 13.0, *)
    var symbolWeight: UIImage.SymbolWeight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

internal struct PhantomSymbolConfig {
    var pointSize: CGFloat?
    var weight: PhantomSymbolWeight?
    var hierarchicalColor: UIColor?

    init(pointSize: CGFloat, weight: PhantomSymbolWeight) {
        self.pointSize = pointSize
        self.weight = weight
    }

    init(hierarchicalColor: UIColor) {
        self.hierarchicalColor = hierarchicalColor
    }
}

extension UIImage {
    internal static func phantomSymbol(_ name: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: name)
        } else {
            return nil
        }
    }

    internal static func phantomSymbol(_ name: String, config: PhantomSymbolConfig) -> UIImage? {
        if #available(iOS 13.0, *) {
            if let color = config.hierarchicalColor {
                if #available(iOS 15.0, *) {
                    return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(hierarchicalColor: color))
                } else {
                    return UIImage(systemName: name)
                }
            } else if let size = config.pointSize, let weight = config.weight {
                return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight.symbolWeight))
            }
            return UIImage(systemName: name)
        } else {
            return nil
        }
    }
}
#endif
