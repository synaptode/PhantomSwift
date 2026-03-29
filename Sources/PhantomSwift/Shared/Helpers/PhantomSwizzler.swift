#if DEBUG
import Foundation

/// Utility for safe method swizzling.
public final class PhantomSwizzler {
    /// Swizzles the implementation of two methods on a given class.
    /// - Parameters:
    ///   - cls: The class to swizzle.
    ///   - originalSelector: The original selector.
    ///   - swizzledSelector: The new selector.
    public static func swizzle(cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(cls,
                                          originalSelector,
                                          method_getImplementation(swizzledMethod),
                                          method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(cls,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    /// Swizzles class methods (e.g. static properties).
    public static func swizzleClassMethod(cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let metaClass = object_getClass(cls) else { return }
        swizzle(cls: metaClass, originalSelector: originalSelector, swizzledSelector: swizzledSelector)
    }
}
#endif
