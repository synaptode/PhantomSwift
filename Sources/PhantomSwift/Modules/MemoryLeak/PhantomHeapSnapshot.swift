#if DEBUG
import Foundation
import UIKit
import MachO

// MARK: - Thread-local accumulator (C-callback safe global)

/// Protected by the snapshot serial queue in `PhantomHeapSnapshot`.
private var _snapshotAccumulator: [String: Int] = [:]

// MARK: - C mach-reader shim

private func phantomReader(
    _ task: task_t,
    _ address: vm_address_t,
    _ size: vm_size_t,
    _ localPtr: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> kern_return_t {
    localPtr?.pointee = UnsafeMutableRawPointer(bitPattern: UInt(address))
    return KERN_SUCCESS
}

// MARK: - C range-enumerator callback

/// Called by the malloc zone introspector for every in-use allocation range.
private let phantomRangeCallback: @convention(c) (
    task_t,                           // task (unused)
    UnsafeMutableRawPointer?,         // context (unused)
    UInt32,                           // type
    UnsafeMutablePointer<vm_range_t>?,// ranges
    UInt32                            // count
) -> Void = { _, _, _, ranges, count in
    guard let ranges else { return }
    for i in 0..<Int(count) {
        let addr = UInt(ranges[i].address)
        guard addr > 0x1000 else { continue }
        guard let raw = UnsafeRawPointer(bitPattern: addr) else { continue }
        // malloc_size == 0 means addr is not owned by any zone — skip
        guard malloc_size(raw) >= MemoryLayout<UInt>.size else { continue }

        // Safe isa read: mask for tagged-pointer safety
        // object_getClass is ObjC-safe and returns nil for non-objects
        let unmanaged = Unmanaged<AnyObject>.fromOpaque(raw)
        guard let cls = object_getClass(unmanaged.takeUnretainedValue()) else { continue }

        let name = NSStringFromClass(cls)
        // Filter runtime / system internals
        guard !name.isEmpty,
              name.first?.isUppercase == true,
              !name.hasPrefix("_"),
              !name.hasPrefix("__"),
              !name.hasPrefix("NSBlock"),
              !name.hasPrefix("OS_"),
              !name.hasPrefix("SwiftNativeNS")
        else { continue }

        _snapshotAccumulator[name, default: 0] += 1
    }
}

// MARK: - PhantomHeapSnapshot

/// Captures and diffs heap object snapshots using live malloc zone enumeration.
///
/// Technique: walks every `malloc_zone_t` registered with the process via the
/// zone's own `introspect->enumerator`, collecting ObjC class names for each
/// well-formed in-use block.  Same approach used by FLEX and Instruments.
///
/// **Call only from a background thread** — the sweep can take 10–100 ms.
public final class PhantomHeapSnapshot {

    // MARK: - Serial queue (protects global accumulator)

    private static let queue = DispatchQueue(label: "com.phantomswift.heap.snapshot")

    // MARK: - Public API

    /// Captures a snapshot of living ObjC-class instances currently on the heap.
    /// Returns a `Set<String>` of distinct class names.
    public static func capture() -> Set<String> {
        Set(instanceCounts().keys)
    }

    /// Returns class name → live instance count for all ObjC objects on the heap.
    /// Pass `filter` to limit results (e.g. exclude framework classes).
    public static func instanceCounts(filter: (String) -> Bool = { _ in true }) -> [String: Int] {
        var result: [String: Int] = [:]
        queue.sync {
            _snapshotAccumulator.removeAll(keepingCapacity: true)
            sweepAllZones()
            result = _snapshotAccumulator.filter { filter($0.key) }
            _snapshotAccumulator.removeAll(keepingCapacity: true)
        }
        return result
    }

    /// Returns class names of objects that are in `after` but not in `before`.
    public static func diff(before: Set<String>, after: Set<String>) -> Set<String> {
        after.subtracting(before)
    }

    // MARK: - Async helper

    /// Asynchronous capture filtered to likely app-defined classes (no framework prefixes).
    public static func captureAsync(completion: @escaping ([String: Int]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let prefixes = ["NS", "UI", "CA", "CF", "AV", "CL", "MK", "WK",
                            "SC", "AR", "RK", "ML", "NW", "GK", "SK", "TV",
                            "App", "Swift"]
            let counts = instanceCounts { name in
                !prefixes.contains(where: { name.hasPrefix($0) }) && !name.hasPrefix("_")
            }
            DispatchQueue.main.async { completion(counts) }
        }
    }

    // MARK: - Zone sweep

    /// Walks every malloc zone and calls `phantomRangeCallback` for each in-use range.
    private static func sweepAllZones() {
        var zonesPtr: UnsafeMutablePointer<vm_address_t>? = nil
        var zoneCount: UInt32 = 0

        let kr = malloc_get_all_zones(mach_task_self_, phantomReader, &zonesPtr, &zoneCount)
        guard kr == KERN_SUCCESS, let zones = zonesPtr else { return }

        for i in 0..<Int(zoneCount) {
            let addr = zones[i]
            guard addr != 0,
                  let zonePtr = UnsafeMutablePointer<malloc_zone_t>(bitPattern: UInt(addr)),
                  let introspect = zonePtr.pointee.introspect,
                  let enumerator = introspect.pointee.enumerator else { continue }

            _ = enumerator(
                mach_task_self_,
                nil,
                UInt32(MALLOC_PTR_IN_USE_RANGE_TYPE),
                addr,
                phantomReader,
                phantomRangeCallback
            )
        }
    }
}
#endif
