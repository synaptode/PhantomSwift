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

    func phantom_applyNavBarAppearance(tintColor: UIColor = PhantomTheme.shared.primaryColor) {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.shadowColor     = .clear
            appearance.titleTextAttributes = [
                .foregroundColor: PhantomTheme.shared.textColor,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navigationController?.navigationBar.standardAppearance   = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance    = appearance
            navigationController?.navigationBar.tintColor = tintColor
        } else {
            navigationController?.navigationBar.barTintColor = PhantomTheme.shared.backgroundColor
            navigationController?.navigationBar.tintColor    = tintColor
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: PhantomTheme.shared.textColor]
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        }
    }
}

extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
}
#endif
