#if DEBUG
import UIKit

/// Protocol for creating custom PhantomSwift plugins.
public protocol PhantomPlugin {
    /// Unique identifier for the plugin.
    var identifier: String { get }
    
    /// Display name in the dashboard.
    var title: String { get }
    
    /// Emoji icon for the dashboard cell.
    var icon: String { get }
    
    /// The entry view controller for the plugin.
    var rootViewController: UIViewController { get }
}
#endif
