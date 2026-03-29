#if DEBUG
import UIKit

/// Manages real-time localization and UI scaling within the app.
public final class PhantomLocaleManager {
    public static let shared = PhantomLocaleManager()
    
    private init() {}
    
    /// Switches the app's language at runtime.
    public func setLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Notify the app that it needs to reload its UI
        NotificationCenter.default.post(name: NSNotification.Name("PhantomLanguageChanged"), object: nil)
        
        // Note: Real system-wide switching on iOS usually requires a restart,
        // but many apps use a custom Bundle subclass for this.
    }
    
    /// Gets the current language code.
    public var currentLanguage: String {
        return (UserDefaults.standard.object(forKey: "AppleLanguages") as? [String])?.first ?? "en"
    }
    
    /// Simulates Dynamic Type scaling. Persists across sessions.
    public func setFontScale(_ scale: CGFloat) {
        UserDefaults.standard.set(Double(scale), forKey: "PhantomFontScale")
        NotificationCenter.default.post(name: .phantomFontScaleChanged, object: scale)
    }
    
    public var currentFontScale: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "PhantomFontScale")
        return saved > 0 ? CGFloat(saved) : 1.0
    }
}

extension NSNotification.Name {
    public static let phantomFontScaleChanged = NSNotification.Name("PhantomFontScaleChanged")
}
#endif
