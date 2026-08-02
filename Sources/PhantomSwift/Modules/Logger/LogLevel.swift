#if DEBUG
import Foundation

/// Priority levels for PhantomSwift logs.
public enum LogLevel: Int, CaseIterable {
    /// Granular technical details
    case verbose = 0
    /// General debug info
    case debug = 1
    /// Normal app flow
    case info = 2
    /// Unusual but non-fatal
    case warning = 3
    /// Error requiring attention
    case error = 4
    /// Fatal, potential crash
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
    
    /// Associated SF Symbol for visual cues
    public var symbolName: String {
        switch self {
        case .verbose: return "magnifyingglass"
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .critical: return "exclamationmark.shield"
        }
    }
}
#endif
