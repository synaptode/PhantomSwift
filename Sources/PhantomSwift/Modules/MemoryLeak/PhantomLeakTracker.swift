#if DEBUG
import Foundation
import UIKit

// MARK: - LeakReport

/// Severity of a detected leak.
public enum LeakSeverity: String, Comparable {
    case potential  = "Potential"   // still alive 3 s after dismiss
    case confirmed  = "Confirmed"   // still alive 8 s after dismiss
    case critical   = "Critical"    // still alive 20 s after dismiss

    public static func < (lhs: LeakSeverity, rhs: LeakSeverity) -> Bool {
        let order: [LeakSeverity] = [.potential, .confirmed, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// Rich model for a detected memory leak instance.
public struct LeakReport {
    public let id: UUID
    public let className: String
    /// Human-readable display name (custom label or class name)
    public let displayName: String
    public let timestamp: Date
    public let callStack: [String]
    public let severity: LeakSeverity
    /// Memory address of the leaked object (hex string)
    public let objectAddress: String
    /// Approx retain count at detection time (clamped; informational only)
    public let retainCount: Int
    /// Source file that called `track(_:)`
    public let file: String?
    /// Source line that called `track(_:)`
    public let line: Int?
    /// Properties discovered via Mirror reflection on the object
    public let mirroredProperties: [(label: String, value: String)]
}

// MARK: - PhantomLeakTracker

/// Advanced memory leak tracker with three escalation tiers,
/// CADisplayLink-based polling, retain-count sampling, Mirror inspection,
/// and per-class instance counting via PhantomHeapSnapshot.
public final class PhantomLeakTracker {

    public static let shared = PhantomLeakTracker()

    // MARK: - Public State

    public private(set) var reports: [LeakReport] = []
    public private(set) var isRunning = false

    // MARK: - Private

    private let lock = NSLock()
    private var pendingBoxes: [TrackedBox] = []
    private var displayLink: CADisplayLink?
    private var isSwizzled = false

    /// Escalation thresholds in seconds after object should have been deallocated.
    private let thresholds: [(delay: TimeInterval, severity: LeakSeverity)] = [
        (3.0,  .potential),
        (8.0,  .confirmed),
        (20.0, .critical),
    ]

    private init() {}

    // MARK: - Control

    /// Starts VC lifecycle swizzle and polling loop.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Swizzle viewDidDisappear once
        if !isSwizzled {
            isSwizzled = true
            let cls = UIViewController.self
            PhantomSwizzler.swizzle(
                cls: cls,
                originalSelector: #selector(UIViewController.viewDidDisappear(_:)),
                swizzledSelector: #selector(UIViewController.phantom_lt_viewDidDisappear(_:)))
        }

        // CADisplayLink polls every ~0.5 sec (30 fps)
        let link = CADisplayLink(target: self, selector: #selector(poll))
        link.preferredFramesPerSecond = 2
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    public func clearReports() {
        lock.lock(); defer { lock.unlock() }
        reports.removeAll()
    }

    // MARK: - Tracking API

    /// Track an arbitrary object for leaks.
    /// - Parameters:
    ///   - object: The object to track (must be a class instance).
    ///   - name: Optional human-readable label.
    ///   - file: Source file (auto-captured via `#file`).
    ///   - line: Source line (auto-captured via `#line`).
    public func track(
        _ object: AnyObject,
        name: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        guard isRunning else { return }

        let className   = String(describing: type(of: object))
        let displayName = name ?? className
        let address     = String(format: "0x%016llx", UInt(bitPattern: ObjectIdentifier(object)))
        let startTime   = Date()

        // Mirror the object's properties now (while still alive)
        let props = mirrorProperties(object)

        lock.lock()
        pendingBoxes.append(TrackedBox(
            object: object,
            className: className,
            displayName: displayName,
            address: address,
            startTime: startTime,
            file: file,
            line: line,
            callStack: Thread.callStackSymbols,
            mirroredProperties: props,
            reportedSeverities: []
        ))
        lock.unlock()
    }

    // MARK: - Polling

    @objc private func poll() {
        guard isRunning else { return }
        lock.lock()
        let snapshot = pendingBoxes
        lock.unlock()

        let now = Date()
        var toAdd: [LeakReport] = []
        var toRemoveIDs: [UUID] = []

        for box in snapshot {
            guard let obj = box.object else {
                // Object was deallocated — remove from tracking
                toRemoveIDs.append(box.id)
                continue
            }

            let elapsed = now.timeIntervalSince(box.startTime)

            // Check each threshold in ascending order
            for (delay, severity) in thresholds {
                guard elapsed >= delay else { break }
                guard !box.reportedSeverities.contains(severity) else { continue }

                // Sample retain count (informational; actual count includes our own ref)
                let rc = max(0, CFGetRetainCount(obj) - 2) // -1 for our hold, -1 for CFGetRetainCount itself

                let report = LeakReport(
                    id: UUID(),
                    className: box.className,
                    displayName: box.displayName,
                    timestamp: Date(),
                    callStack: box.callStack,
                    severity: severity,
                    objectAddress: box.address,
                    retainCount: rc,
                    file: box.file,
                    line: box.line,
                    mirroredProperties: box.mirroredProperties
                )
                toAdd.append(report)
                box.reportedSeverities.insert(severity)
                PhantomEventBus.shared.post(.memoryLeakDetected(report))
                break // Only escalate one tier per poll cycle
            }
        }

        // Prune dead boxes on main thread (already on main via CADisplayLink)
        if !toRemoveIDs.isEmpty {
            lock.lock()
            pendingBoxes.removeAll { box in
                toRemoveIDs.contains(box.id)
            }
            lock.unlock()
        }

        // Persist new reports
        if !toAdd.isEmpty {
            lock.lock()
            reports.append(contentsOf: toAdd)
            lock.unlock()
        }
    }

    // MARK: - Mirror Inspection

    private func mirrorProperties(_ object: AnyObject) -> [(label: String, value: String)] {
        var result: [(String, String)] = []
        let mirror = Mirror(reflecting: object)
        for child in mirror.children.prefix(20) {
            guard let label = child.label else { continue }
            let value: String
            switch child.value {
            case let v as AnyObject:
                value = "<\(type(of: child.value))> @ \(String(format: "0x%llx", UInt(bitPattern: ObjectIdentifier(v))))"
            default:
                value = "\(child.value)"
            }
            result.append((label, value))
        }
        return result
    }
}

// MARK: - TrackedBox

private final class TrackedBox {
    let id: UUID = UUID()
    weak var object: AnyObject?
    let className: String
    let displayName: String
    let address: String
    let startTime: Date
    let file: String?
    let line: Int?
    let callStack: [String]
    let mirroredProperties: [(label: String, value: String)]
    var reportedSeverities: Set<LeakSeverity>

    init(
        object: AnyObject,
        className: String,
        displayName: String,
        address: String,
        startTime: Date,
        file: String?,
        line: Int?,
        callStack: [String],
        mirroredProperties: [(label: String, value: String)],
        reportedSeverities: Set<LeakSeverity>
    ) {
        self.object = object
        self.className = className
        self.displayName = displayName
        self.address = address
        self.startTime = startTime
        self.file = file
        self.line = line
        self.callStack = callStack
        self.mirroredProperties = mirroredProperties
        self.reportedSeverities = reportedSeverities
    }
}

// MARK: - UIViewController Swizzle Extension

extension UIViewController {
    @objc func phantom_lt_viewDidDisappear(_ animated: Bool) {
        self.phantom_lt_viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            // Schedule tracking after a brief delay so the VC has a chance to fully
            // release child references (e.g. embedded VCs, views)
            let vc = self
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PhantomLeakTracker.shared.track(vc, name: String(describing: type(of: vc)))
            }
        }
    }
}

#endif
