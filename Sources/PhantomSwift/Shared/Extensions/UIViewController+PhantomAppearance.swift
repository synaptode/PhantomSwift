#if DEBUG
import UIKit

internal extension UIViewController {
    /// Sets up the standard Phantom appearance for the view controller's view and navigation bar.
    func setupPhantomAppearance(titleFont: UIFont? = nil) {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor

            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
            if let font = titleFont {
                attributes[.font] = font
            }
            appearance.titleTextAttributes = attributes

            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }
}
#endif
