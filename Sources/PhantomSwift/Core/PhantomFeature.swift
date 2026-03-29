#if DEBUG
import Foundation

/// Defines all available feature modules within PhantomSwift.
public enum PhantomFeature: String, CaseIterable {
    /// Network traffic monitoring
    case network
    /// API request/response interception and mocking
    case interceptor
    /// Centralized application logging
    case logger
    /// Automated memory leak detection
    case memoryLeak
    /// UI hierarchy inspection and live editing
    case uiInspector
    /// Sandbox, UserDefaults, and database inspection
    case storage
    /// Real-time CPU, Memory, and FPS monitoring
    case performance
    /// QA bug reporting and testing utilities
    case qa
    /// Security audit and jailbreak detection
    case security
    /// SwiftUI render and state tracking
    case swiftUI
    /// Accessibility audit for UI elements
    case accessibility
    /// Real-time localization and system environment spoofing
    case environment
    /// Cross-process logging for App Extensions (Widgets, etc.)
    case extensionSidekick
    /// Simulated poor network conditions
    case badNetwork
    /// Main thread UI hang/jank detection
    case hangDetector
    /// Entire App State (Defaults, Files) snapshot and restore
    case stateSnapshot
    /// Real-time tracking event interceptor
    case analytics
    /// Visual object relationship and leak finder
    case memoryGraph
    /// Visual audit for image/video memory and sizing
    case assetInspector
    /// Feature flags management panel
    case featureFlags
    /// Main-thread violation checker
    case mainThreadChecker
    /// Network waterfall timeline
    case waterfall
    /// Remote WebSocket debug server
    case remoteServer
    /// Deep link and Universal Link launcher & history
    case deepLinkTester
    /// Crash log viewer — NSException captures + MetricKit crash diagnostics
    case crashLogs
    /// Live Auto Layout constraint conflict detector
    case layoutConflicts
    /// Simulate APNs push notifications locally using UNUserNotificationCenter
    case pushNotificationSimulator
    /// Inspect BGTaskScheduler permitted and pending background task requests
    case backgroundTaskInspector
    /// ObjC runtime browser — inspect loaded classes, methods, properties, and ivars
    case runtimeBrowser
}
#endif
