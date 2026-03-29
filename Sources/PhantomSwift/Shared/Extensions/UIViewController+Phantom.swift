#if DEBUG
import UIKit

extension UIViewController {
    /// Recursively finds the top-most visible view controller.
    var topMost: UIViewController? {
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMost ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMost ?? tab
        }
        if let presented = presentedViewController {
            return presented.topMost
        }
        return self
    }
}

extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
}
#endif
