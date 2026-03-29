#if DEBUG
import UIKit

/// Handles gesture-based triggers for PhantomSwift.
internal final class PhantomGestureHandler {
    internal static let shared = PhantomGestureHandler()
    
    internal func start() {
        // Swizzle UIApplication to intercept events globally (including Shake)
        let cls = UIApplication.self
        let original = #selector(cls.sendEvent(_:))
        let swizzled = #selector(cls.phantom_sendEvent(_:))
        PhantomSwizzler.swizzle(cls: cls, originalSelector: original, swizzledSelector: swizzled)
    }
}

extension UIApplication {
    @objc func phantom_sendEvent(_ event: UIEvent) {
        // Call original implementation
        self.phantom_sendEvent(event)
        
        // Intercept Shake gesture
        if event.type == .motion && event.subtype == .motionShake && PhantomSwift.shared.config.triggers.contains(.shake) {
            PhantomSwift.shared.showDashboard()
        }
    }
}
#endif
