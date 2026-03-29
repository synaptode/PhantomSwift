#if DEBUG
import Foundation
import OSLog

// MARK: - PhantomOSLogBridge

/// Bridges the unified logging system (OSLog) into PhantomSwift's `LogStore`.
///
/// On iOS 15+ the bridge uses `OSLogStore` to import all log entries emitted via
/// `Logger` (any subsystem/category) into PhantomSwift's console.  On older OS
/// versions the bridge is a no-op — the `print`-based fallback in `PhantomLog`
/// already surfaces developer logs.
///
/// ## Usage
/// ```swift
/// PhantomSwift.shared.configure { cfg in
///     cfg.enableOSLogBridge = true   // opt-in (default: false)
/// }
/// ```
/// After activation, log entries from **all** subsystems visible to the process
/// appear in the Logger panel alongside `PhantomLog.*` entries, tagged with their
/// OSLog category.
internal final class PhantomOSLogBridge {

    internal static let shared = PhantomOSLogBridge()
    private init() {}

    // MARK: - State

    private var isRunning = false
    private var pollingTimer: Timer?
    /// Stored as `Any?` to avoid referencing `OSLogPosition` at class level (iOS 15+).
    private var lastPositionAny: Any?
    private let queue = DispatchQueue(label: "com.phantomswift.oslog.bridge", qos: .utility)

    /// How often to poll the OSLogStore for new entries (seconds).
    private let pollingInterval: TimeInterval = 2.0

    // MARK: - Lifecycle

    /// Start polling OSLog and forwarding new entries to `LogStore`.
    internal func start() {
        guard !isRunning else { return }

        if #available(iOS 15.0, *) {
            isRunning = true
            scheduleFirstPoll()
        }
        // No-op on < iOS 15
    }

    /// Stop polling.
    internal func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isRunning = false
    }

    // MARK: - Polling

    @available(iOS 15.0, *)
    private func scheduleFirstPoll() {
        // Anchor to "now" so we only read future entries on subsequent polls.
        queue.async { [weak self] in
            guard let self else { return }
            if let store = try? OSLogStore(scope: .currentProcessIdentifier) {
                self.lastPositionAny = store.position(date: Date())
            }
            DispatchQueue.main.async { [weak self] in self?.scheduleTimer() }
        }
    }

    private func scheduleTimer() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        if #available(iOS 15.0, *) {
            queue.async { [weak self] in
                self?.importNewEntries()
            }
        }
    }

    @available(iOS 15.0, *)
    private func importNewEntries() {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }

        let position: OSLogPosition
        if let last = lastPositionAny as? OSLogPosition {
            position = last
        } else {
            position = store.position(date: Date().addingTimeInterval(-30))
        }

        let predicate = NSPredicate(format: "subsystem != nil")
        guard let entries = try? store.getEntries(at: position, matching: predicate) else { return }

        var newPosition: OSLogPosition?
        var logEntries: [LogEntry] = []

        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else { continue }

            // Map OSLog level → PhantomLog level
            let level = phantomLevel(from: logEntry.level)

            // Skip debug/trace noise from Apple frameworks unless they're from the app subsystem
            let appBundleID = Bundle.main.bundleIdentifier ?? ""
            let isAppSubsystem = logEntry.subsystem.hasPrefix(appBundleID)
            if !isAppSubsystem && level.rawValue < LogLevel.warning.rawValue { continue }

            let tag = "\(logEntry.subsystem)/\(logEntry.category)"
            let entry = LogEntry(
                level: level,
                message: logEntry.composedMessage,
                tag: tag,
                timestamp: logEntry.date,
                file: "OSLog",
                function: logEntry.category,
                line: 0
            )
            logEntries.append(entry)

            newPosition = store.position(date: logEntry.date.addingTimeInterval(0.001))
        }

        if let pos = newPosition {
            lastPositionAny = pos
        }

        // Add to store on a non-barrier async so we don't block the UI
        for entry in logEntries {
            LogStore.shared.add(entry)
        }
    }

    // MARK: - Level Mapping

    @available(iOS 15.0, *)
    private func phantomLevel(from osLevel: OSLogEntryLog.Level) -> LogLevel {
        switch osLevel {
        case .undefined:  return .verbose
        case .debug:      return .debug
        case .info:       return .info
        case .notice:     return .info
        case .error:      return .error
        case .fault:      return .critical
        @unknown default: return .info
        }
    }
}
#endif
