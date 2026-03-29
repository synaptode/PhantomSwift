#if DEBUG
import Foundation

/// A bus for communicating between the main app and App Extensions (Widgets, etc.)
public final class PhantomExtensionBus {
    public static let shared = PhantomExtensionBus()
    
    /// The App Group ID used for sharing data.
    public var appGroupId: String?
    
    private let defaultsSuite: UserDefaults?
    
    private init() {
        // We'll try to find a reasonable suite if not provided, 
        // but typically the user must provide the App Group ID.
        self.defaultsSuite = UserDefaults(suiteName: appGroupId)
    }
    
    /// Posts a log from an extension.
    public func postLog(_ message: String, tag: String = "Extension") {
        guard let suite = defaultsSuite else { return }
        
        var logs = suite.stringArray(forKey: "com.phantomswift.extension.logs") ?? []
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logs.append("[\(timestamp)] [\(tag)] \(message)")
        
        // Keep only last 100 logs
        if logs.count > 100 { logs.removeFirst() }
        
        suite.set(logs, forKey: "com.phantomswift.extension.logs")
        suite.synchronize()
    }
    
    /// Retrieves all logs from extensions.
    public func getLogs() -> [String] {
        return defaultsSuite?.stringArray(forKey: "com.phantomswift.extension.logs") ?? []
    }
}
#endif
