#if DEBUG
import UIKit

/// Handles gesture-based triggers for PhantomSwift.
internal final class PhantomGestureHandler {
    internal static let shared = PhantomGestureHandler()
    private var isStarted = false
    internal static var lastShakeTimestamp: TimeInterval = 0

    
    internal func start() {
        guard !isStarted else { return }
        isStarted = true

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
        
        // Intercept Shake gesture with debounce and toggle
        let isShake = event.type == .motion && event.subtype == .motionShake
        if isShake && PhantomSwift.shared.config.triggers.contains(.shake) {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - PhantomGestureHandler.lastShakeTimestamp > 0.5 else { return }
            PhantomGestureHandler.lastShakeTimestamp = now
            PhantomSwift.shared.toggleDashboard()
        }
    }
}
#endif
