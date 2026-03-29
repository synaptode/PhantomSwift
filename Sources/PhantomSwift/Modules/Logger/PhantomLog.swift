#if DEBUG
import Foundation

/// Public logging API for PhantomSwift.
public final class PhantomLog {
    /// Logs a verbose message.
    public static func verbose(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    /// Logs a debug message.
    public static func debug(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    /// Logs an info message.
    public static func info(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    /// Logs a warning message.
    public static func warning(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    /// Logs an error message.
    public static func error(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    /// Logs a critical message.
    public static func critical(_ message: String, tag: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, tag: tag, file: file, function: function, line: line)
    }
    
    private static func log(level: LogLevel, message: String, tag: String?, file: String, function: String, line: Int) {
        let entry = LogEntry(
            level: level,
            message: message,
            tag: tag,
            file: file,
            function: function,
            line: line
        )
        LogStore.shared.add(entry)
        
        // Also print to console for development convenience
        #if DEBUG
        print("\(entry.formatted) (\((file as NSString).lastPathComponent):\(line))")
        #endif
    }
}
#endif
