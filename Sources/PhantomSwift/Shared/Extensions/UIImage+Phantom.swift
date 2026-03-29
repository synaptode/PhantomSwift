#if DEBUG
import UIKit

extension UIImage {
    internal static func phantomSymbol(_ name: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: name)
        } else {
            return nil
        }
    }
}
#endif
