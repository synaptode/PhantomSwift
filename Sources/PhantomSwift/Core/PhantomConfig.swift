#if DEBUG
import Foundation
import UIKit

/// Configuration object for PhantomSwift.
public struct PhantomConfig {
    /// The operating environment. Defaults to `.dev`.
    public var environment: PhantomEnvironment = .dev
    
    /// The trigger methods for the HUD. Defaults to `[.shake]`.
    public var triggers: [TriggerType] = [.shake]
    
    /// The theme for the UI. Defaults to `.dark`.
    public var theme: ThemeType = .dark
    
    /// Custom app shortcuts for the QA module.
    public var shortcuts: [AppShortcut] = []

    /// When `true`, PhantomSwift polls `OSLogStore` (iOS 15+) on a 2-second
    /// interval and imports all new log entries into the Logger panel.
    /// Entries from non-app subsystems below `warning` level are filtered.
    /// Has no effect on iOS < 15. Defaults to `false`.
    public var enableOSLogBridge: Bool = false
    
    /// Defines how PhantomSwift is triggered.
    public enum TriggerType {
        /// Trigger by shaking the device.
        case shake
        /// Modern Dynamic Island style overlay.
        case dynamicIsland
    }
    
    /// Defines the UI theme.
    public enum ThemeType {
        /// Dark theme (Default).
        case dark
        /// Light theme.
        case light
        /// Follows system interface style.
        case auto
    }
    
    
    public init() {}
}

/// Represents a custom quick action in the QA module.
public struct AppShortcut {
    public let title: String
    public let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}
#endif
