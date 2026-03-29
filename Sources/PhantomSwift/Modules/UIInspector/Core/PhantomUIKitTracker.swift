#if DEBUG
import UIKit

/// Hooks into the UIKit layout cycle to track view updates.
internal final class PhantomUIKitTracker {
    static let shared = PhantomUIKitTracker()
    private var isSwizzled = false
    
    func start() {
        guard !isSwizzled else { return }
        isSwizzled = true
        
        PhantomSwizzler.swizzle(
            cls: UIView.self,
            originalSelector: #selector(UIView.layoutSubviews),
            swizzledSelector: #selector(UIView.phantom_layoutSubviews)
        )
    }
}

extension UIView {
    @objc func phantom_layoutSubviews() {
        // Call original (which is now phantom_layoutSubviews because of implementation exchange)
        self.phantom_layoutSubviews()
        
        // Track the update if it's not a private system view
        let className = String(describing: type(of: self))
        if !className.hasPrefix("_") && !className.contains("Phantom") {
            PhantomRenderStore.shared.track(viewName: className, type: .uiKit)
        }
    }
}
#endif
