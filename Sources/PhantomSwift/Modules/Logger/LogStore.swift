#if DEBUG
import Foundation

/// Thread-safe circular buffer for logs.
public final class LogStore {
    public static let shared = LogStore()

    private let queue = DispatchQueue(label: "com.phantomswift.logger.store", attributes: .concurrent)

    // O(1) ring buffer: avoids O(n) removeFirst shifts
    private var buffer: [LogEntry?]
    private var head = 0   // index of oldest entry
    private var count = 0
    private let maxCount: Int

    private init(maxCount: Int = 1000) {
        self.maxCount = maxCount
        self.buffer = Array(repeating: nil, count: maxCount)
    }

    /// Adds a new log entry to the store. O(1).
    public func add(_ log: LogEntry) {
        queue.async(flags: .barrier) {
            let slot = (self.head + self.count) % self.maxCount
            self.buffer[slot] = log
            if self.count < self.maxCount {
                self.count += 1
            } else {
                // Buffer full: advance head to overwrite oldest
                self.head = (self.head + 1) % self.maxCount
            }
        }
        // Post event OUTSIDE the barrier to prevent priority inversion
        queue.async { [log] in
            PhantomEventBus.shared.post(.logAdded(log))
        }
    }

    /// Returns all stored logs in insertion order. O(n).
    public func getAll() -> [LogEntry] {
        queue.sync {
            var result: [LogEntry] = []
            result.reserveCapacity(count)
            for i in 0..<count {
                if let entry = buffer[(head + i) % maxCount] {
                    result.append(entry)
                }
            }
            return result
        }
    }

    /// Clears all stored logs. O(1).
    public func clear() {
        queue.async(flags: .barrier) {
            self.buffer = Array(repeating: nil, count: self.maxCount)
            self.head = 0
            self.count = 0
        }
    }
}
#endif
