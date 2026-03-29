#if DEBUG
import Foundation

/// Represents a single log entry.
public struct LogEntry: Identifiable {
    public let id: UUID
    public let level: LogLevel
    public let message: String
    public let tag: String?
    public let timestamp: Date
    public let file: String
    public let function: String
    public let line: Int
    
    public init(id: UUID = UUID(),
                level: LogLevel,
                message: String,
                tag: String?,
                timestamp: Date = Date(),
                file: String,
                function: String,
                line: Int) {
        self.id = id
        self.level = level
        self.message = message
        self.tag = tag
        self.timestamp = timestamp
        self.file = file
        self.function = function
        self.line = line
    }
    
    /// Formatted log string for display.
    public var formatted: String {
        "[\(level.emoji) \(level.name)] \(message)"
    }
}
#endif
