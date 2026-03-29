#if DEBUG
import Foundation
import UIKit
import MetricKit

// MARK: - CrashEntry

internal struct CrashEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: CrashType
    let reason: String
    let callStack: [String]
    let appVersion: String
    let osVersion: String

    enum CrashType: String, Codable {
        case exception = "Exception"
        case metricKit = "MetricKit"
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: CrashType,
        reason: String,
        callStack: [String]
    ) {
        self.id         = id
        self.date       = date
        self.type       = type
        self.reason     = reason
        self.callStack  = callStack
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        self.osVersion  = UIDevice.current.systemVersion
    }
}

// MARK: - PhantomCrashLogStore

/// Captures uncaught NSExceptions at runtime and ingests MetricKit crash diagnostics
/// from the previous 24-hour window. Persists entries to disk so crashes from prior
/// sessions survive an app restart and remain visible on relaunch.
internal final class PhantomCrashLogStore {

    internal static let shared = PhantomCrashLogStore()

    private let queue     = DispatchQueue(label: "com.phantomswift.crashlog", attributes: .concurrent)
    private var _entries: [CrashEntry] = []
    private let storeURL: URL
    private let maxCount  = 100

    private var _observers: [UUID: () -> Void] = [:]

    private init() {
        let lib  = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        storeURL = lib.appendingPathComponent("PhantomCrashLogs.json")
        loadFromDisk()
    }

    // MARK: - Lifecycle

    internal func start() {
        installExceptionHandler()
    }

    // MARK: - Data Access

    internal var count: Int { queue.sync { _entries.count } }

    internal func getAll() -> [CrashEntry] {
        queue.sync { _entries.sorted { $0.date > $1.date } }
    }

    internal func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            _entries.removeAll()
            try? FileManager.default.removeItem(at: storeURL)
        }
        notifyObservers()
    }

    @discardableResult
    internal func addObserver(_ block: @escaping () -> Void) -> UUID {
        let id = UUID()
        queue.async(flags: .barrier) { [weak self] in
            self?._observers[id] = block
        }
        return id
    }

    internal func removeObserver(_ id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?._observers.removeValue(forKey: id)
        }
    }

    // MARK: - MetricKit ingestion (iOS 14+)

    @available(iOS 14.0, *)
    internal func ingestCrashDiagnostics(_ crashes: [MXCrashDiagnostic]) {
        for crash in crashes {
            // MXCallStackTree doesn't expose a public Swift-friendly traversal API;
            // extract the JSON representation and use it as the call stack display.
            let stackText = crash.callStackTree.jsonRepresentation()
            let frames: [String]
            if let json = try? JSONSerialization.jsonObject(with: stackText) as? [String: Any],
               let callStacks = json["callStacks"] as? [[String: Any]] {
                frames = callStacks.flatMap { cs -> [String] in
                    guard let rootFrames = cs["callStackRootFrames"] as? [[String: Any]] else { return [] }
                    return rootFrames.map { frame -> String in
                        let bin  = frame["binaryName"] as? String ?? "?"
                        let addr = (frame["address"] as? Int64).map { String(format: "0x%llx", $0) } ?? "?"
                        return "  \(bin)  \(addr)"
                    }
                }
            } else {
                frames = [String(data: stackText, encoding: .utf8) ?? "(call stack unavailable)"]
            }
            let reason: String
            if let r = crash.terminationReason {
                reason = r
            } else if let exc = crash.exceptionType {
                reason = "Exception type \(exc.intValue)"
            } else {
                reason = "(unknown)"
            }
            addEntry(CrashEntry(
                type: .metricKit,
                reason: reason,
                callStack: frames.isEmpty ? ["(no stack available)"] : frames
            ))
        }
    }

    // MARK: - Entry Storage

    private func addEntry(_ entry: CrashEntry) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            _entries.insert(entry, at: 0)
            if _entries.count > maxCount { _entries = Array(_entries.prefix(maxCount)) }
            saveToDisk()
        }
        notifyObservers()
    }

    /// Synchronous barrier write — safe to call just before process termination.
    private func addEntrySync(_ entry: CrashEntry) {
        queue.sync(flags: .barrier) {
            _entries.insert(entry, at: 0)
            if _entries.count > maxCount { _entries = Array(_entries.prefix(maxCount)) }
            saveToDisk()
        }
    }

    // MARK: - Uncaught Exception Handler

    private static var previousHandler: NSUncaughtExceptionHandler?

    private func installExceptionHandler() {
        PhantomCrashLogStore.previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            let entry = CrashEntry(
                type: .exception,
                reason: "\(exception.name.rawValue): \(exception.reason ?? "(no reason)")",
                callStack: exception.callStackSymbols
            )
            // Must be synchronous — app is about to terminate.
            PhantomCrashLogStore.shared.addEntrySync(entry)
            // Forward to any previously installed handler (e.g. Firebase Crashlytics).
            PhantomCrashLogStore.previousHandler?(exception)
        }
    }

    // MARK: - Disk Persistence

    private func loadFromDisk() {
        guard
            let data    = try? Data(contentsOf: storeURL),
            let decoded = try? JSONDecoder().decode([CrashEntry].self, from: data)
        else { return }
        _entries = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(_entries) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Observer Notification

    private func notifyObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.sync { self._observers.values }.forEach { $0() }
        }
    }
}
#endif
