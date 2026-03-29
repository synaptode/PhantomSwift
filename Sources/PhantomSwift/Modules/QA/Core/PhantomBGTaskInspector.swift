#if DEBUG
import Foundation
import UIKit
import BackgroundTasks

// MARK: - BGTaskRecord

/// Snapshot of a background task's current state.
internal struct BGTaskRecord {
    enum TaskType: String {
        case appRefresh  = "App Refresh"
        case processing  = "Processing"
        case unknown     = "Unknown"
    }

    let identifier: String
    var type: TaskType
    var isPending: Bool
    var earliestBeginDate: Date?
    var lastSeenPending: Date?
    var lastRefreshed: Date

    init(identifier: String) {
        self.identifier = identifier
        // Infer type from common identifier conventions
        let lower = identifier.lowercased()
        if lower.contains("refresh") || lower.contains("fetch") {
            self.type = .appRefresh
        } else if lower.contains("process") || lower.contains("sync") || lower.contains("upload") || lower.contains("download") {
            self.type = .processing
        } else {
            self.type = .unknown
        }
        self.isPending = false
        self.earliestBeginDate = nil
        self.lastSeenPending = nil
        self.lastRefreshed = Date()
    }
}

// MARK: - PhantomBGTaskInspector

/// Inspects `BGTaskScheduler` permitted identifiers (from Info.plist) and
/// live pending task requests.
///
/// **Requirements**: iOS 13.0+. App must list identifiers under
/// `BGTaskSchedulerPermittedIdentifiers` key in Info.plist.
///
/// **How it works** — no swizzling required:
/// 1. Reads `BGTaskSchedulerPermittedIdentifiers` from `Bundle.main.infoDictionary`
///    to enumerate every task the app has declared.
/// 2. Periodically calls the public `BGTaskScheduler.shared.getPendingTaskRequests`
///    to reflect which tasks are currently queued.
/// 3. Provides an observer API so `BGTaskInspectorVC` can refresh reactively.
@available(iOS 13.0, *)
internal final class PhantomBGTaskInspector {

    internal static let shared = PhantomBGTaskInspector()
    private init() {}

    // MARK: - State

    private let queue = DispatchQueue(label: "com.phantomswift.bgtaskinspector", attributes: .concurrent)
    private var _records: [BGTaskRecord] = []
    private var _observers: [UUID: ([BGTaskRecord]) -> Void] = [:]
    private var refreshTimer: Timer?

    /// All known background task identifiers — static from Info.plist.
    private(set) var permittedIdentifiers: [String] = []

    var records: [BGTaskRecord] {
        queue.sync { _records }
    }

    var permittedCount: Int { permittedIdentifiers.count }
    var pendingCount: Int { records.filter { $0.isPending }.count }

    // MARK: - Start

    internal func start() {
        permittedIdentifiers = loadPermittedIdentifiers()
        _records = permittedIdentifiers.map { BGTaskRecord(identifier: $0) }
        refresh()
    }

    // MARK: - Info.plist reading

    private func loadPermittedIdentifiers() -> [String] {
        let keys = [
            "BGTaskSchedulerPermittedIdentifiers",   // standard key
            "UIBackgroundModes"                      // fallback for older apps
        ]
        for key in keys {
            if let ids = Bundle.main.object(forInfoDictionaryKey: key) as? [String], !ids.isEmpty {
                // Filter out UIBackgroundModes values that aren't task identifiers
                let taskIds = ids.filter { $0.contains(".") || $0.count > 10 }
                if !taskIds.isEmpty { return taskIds }
            }
        }
        // Also check processed info dict
        if let ids = Bundle.main.infoDictionary?["BGTaskSchedulerPermittedIdentifiers"] as? [String] {
            return ids
        }
        return []
    }

    // MARK: - Refresh

    /// Polls `BGTaskScheduler.shared.getPendingTaskRequests` and merges results.
    @discardableResult
    internal func refresh() -> PhantomBGTaskInspector {
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
            guard let self else { return }

            self.queue.async(flags: .barrier) {
                let now = Date()
                // Update existing records
                for i in 0..<self._records.count {
                    let id = self._records[i].identifier
                    if let match = requests.first(where: { $0.identifier == id }) {
                        self._records[i].isPending = true
                        self._records[i].earliestBeginDate = match.earliestBeginDate
                        self._records[i].lastSeenPending = now
                        // Refine type from actual request class
                        self._records[i].type = Self.taskType(from: match)
                    } else {
                        self._records[i].isPending = false
                        self._records[i].earliestBeginDate = nil
                    }
                    self._records[i].lastRefreshed = now
                }

                // Capture pending requests whose identifiers aren't in our permitted list
                for req in requests {
                    if !self._records.contains(where: { $0.identifier == req.identifier }) {
                        var record = BGTaskRecord(identifier: req.identifier)
                        record.isPending = true
                        record.earliestBeginDate = req.earliestBeginDate
                        record.lastSeenPending = now
                        record.type = Self.taskType(from: req)
                        record.lastRefreshed = now
                        self._records.append(record)
                    }
                }

                let snapshot = self._records
                let observers = self._observers.values.map { $0 }
                DispatchQueue.main.async {
                    observers.forEach { $0(snapshot) }
                }
            }
        }
        return self
    }

    private static func taskType(from request: BGTaskRequest) -> BGTaskRecord.TaskType {
        let typeName = String(describing: type(of: request))
        if typeName.contains("AppRefresh") { return .appRefresh }
        if typeName.contains("Processing") { return .processing }
        return .unknown
    }

    // MARK: - Periodic refresh

    internal func startAutoRefresh(interval: TimeInterval = 5) {
        stopAutoRefresh()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    internal func stopAutoRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer?.invalidate()
            self?.refreshTimer = nil
        }
    }

    // MARK: - Observers

    @discardableResult
    internal func addObserver(_ handler: @escaping ([BGTaskRecord]) -> Void) -> UUID {
        let id = UUID()
        queue.async(flags: .barrier) { [weak self] in
            self?._observers[id] = handler
        }
        return id
    }

    internal func removeObserver(_ id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?._observers.removeValue(forKey: id)
        }
    }

    // MARK: - Cancel pending

    /// Cancels all pending background task requests submitted by the app.
    internal func cancelAllPending(completion: @escaping () -> Void) {
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
            for req in requests {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: req.identifier)
            }
            self?.refresh()
            DispatchQueue.main.async { completion() }
        }
    }
}
#endif
