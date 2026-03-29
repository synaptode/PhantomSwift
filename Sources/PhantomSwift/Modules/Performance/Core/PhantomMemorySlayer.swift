#if DEBUG
import UIKit
import MachO

// MARK: - MemorySnapshot

/// A point-in-time capture of the app's memory state.
internal struct MemorySnapshot {
    internal let label: String
    internal let timestamp: Date
    /// Physical memory footprint in bytes (resident size).
    internal let footprintBytes: Int64
    /// IDs of all objects tracked at snapshot time.
    internal let trackedObjectIDs: Set<String>
}

// MARK: - PhantomMemorySlayer

/// Simulates memory pressure, flushes caches, reports physical footprint,
/// and captures before/after snapshots for memory-diff analysis.
internal final class PhantomMemorySlayer {

    internal static let shared = PhantomMemorySlayer()
    private init() {}

    // MARK: - Stored snapshots

    private(set) var beforeSnapshot: MemorySnapshot?
    private(set) var afterSnapshot:  MemorySnapshot?

    // MARK: - Simulate memory warning

    /// Posts `UIApplication.didReceiveMemoryWarningNotification`.
    /// All `NSCache` instances, `URLSession`, and view controllers that override
    /// `didReceiveMemoryWarning()` will flush their contents — no private APIs used.
    internal func simulateMemoryWarning() {
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: UIApplication.shared
        )
    }

    // MARK: - Cache flush

    /// Clears `URLCache.shared` (disk + memory) then sends a memory-warning
    /// notification so `NSCache` observers are also purged.
    internal func clearCaches() {
        URLCache.shared.removeAllCachedResponses()
        simulateMemoryWarning()
    }

    // MARK: - Physical footprint

    /// Current resident memory size for this process (bytes).
    /// Uses the public Mach `task_info` API — identical to what Xcode's memory
    /// gauge reads. Safe and App Store compliant.
    internal func currentFootprintBytes() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
    }

    // MARK: - Snapshots

    /// Captures the current memory state as the "before" baseline.
    @discardableResult
    internal func takeBeforeSnapshot() -> MemorySnapshot {
        let snap = makeSnapshot(label: "Before")
        beforeSnapshot = snap
        return snap
    }

    /// Captures the current memory state as the "after" comparison point.
    @discardableResult
    internal func takeAfterSnapshot() -> MemorySnapshot {
        let snap = makeSnapshot(label: "After")
        afterSnapshot = snap
        return snap
    }

    /// Discards both snapshots so the user can start a new diff cycle.
    internal func clearSnapshots() {
        beforeSnapshot = nil
        afterSnapshot  = nil
    }

    /// Objects that exist in the current tracker list but were NOT present in
    /// the `before` snapshot — i.e. newly allocated objects.
    internal func diffedObjects() -> [PhantomTrackedObject] {
        guard let before = beforeSnapshot else { return [] }
        return PhantomObjectTracker.shared.trackedObjects
            .filter { !before.trackedObjectIDs.contains($0.id) }
    }

    // MARK: - Private helpers

    private func makeSnapshot(label: String) -> MemorySnapshot {
        let ids = Set(PhantomObjectTracker.shared.trackedObjects.map { $0.id })
        return MemorySnapshot(
            label: label,
            timestamp: Date(),
            footprintBytes: currentFootprintBytes(),
            trackedObjectIDs: ids
        )
    }
}

// MARK: - Formatting

extension PhantomMemorySlayer {
    /// Human-readable byte size: "3.4 MB", "512 KB".
    static func formatBytes(_ bytes: Int64) -> String {
        let absBytes = abs(bytes)
        if absBytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        return String(format: "%.0f KB", Double(bytes) / 1_024)
    }
}
#endif
