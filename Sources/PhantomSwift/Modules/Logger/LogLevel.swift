#if DEBUG
import Foundation

/// Priority levels for PhantomSwift logs.
public enum LogLevel: Int, CaseIterable {
    /// 🔍 Granular technical details
    case verbose = 0
    /// 🐛 General debug info
    case debug = 1
    /// ℹ️ Normal app flow
    case info = 2
    /// ⚠️ Unusual but non-fatal
    case warning = 3
    /// ❌ Error requiring attention
    case error = 4
    /// 🚨 Fatal, potential crash
    case critical = 5
    
    /// User-friendly name
    public var name: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    /// Associated emoji for visual cues
    public var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}
#endif
