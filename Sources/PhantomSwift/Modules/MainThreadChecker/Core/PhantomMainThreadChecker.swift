#if DEBUG
import UIKit
import ObjectiveC

/// Detects UIKit calls made from background threads — a common source of crashes.
/// Swizzles key UIView methods to verify they run on the main thread.
internal final class PhantomMainThreadChecker {
    internal static let shared = PhantomMainThreadChecker()

    private let queue = DispatchQueue(label: "com.phantomswift.mainthread", attributes: .concurrent)
    private var violations: [ThreadViolation] = []
    private let maxViolations = 500
    private var isStarted = false

    private init() {}

    // MARK: - Model

    internal struct ThreadViolation: Identifiable {
        let id = UUID()
        let timestamp: Date
        let className: String
        let methodName: String
        let threadName: String
        let threadID: UInt64
        let callStack: [String]
        let isMainThread: Bool

        var shortCallStack: String {
            // Filter to only app frames, skip system/phantom frames
            let appFrames = callStack.filter { frame in
                !frame.contains("PhantomSwift") &&
                !frame.contains("UIKitCore") &&
                !frame.contains("CoreFoundation") &&
                !frame.contains("libdispatch") &&
                !frame.contains("libsystem") &&
                !frame.contains("Foundation")
            }
            return appFrames.prefix(5).joined(separator: "\n")
        }
    }

    // MARK: - Start/Stop

    internal func start() {
        guard !isStarted else { return }
        isStarted = true
        swizzleMethods()
    }

    internal func stop() {
        isStarted = false
    }

    // MARK: - Data Access

    internal func getViolations() -> [ThreadViolation] {
        return queue.sync { violations }
    }

    internal func clearViolations() {
        queue.async(flags: .barrier) { [weak self] in
            self?.violations.removeAll()
        }
    }

    internal var violationCount: Int {
        return queue.sync { violations.count }
    }

    // MARK: - Violation Recording

    internal func recordViolation(className: String, methodName: String) {
        guard isStarted else { return }

        var threadID: UInt64 = 0
        pthread_threadid_np(nil, &threadID)

        let violation = ThreadViolation(
            timestamp: Date(),
            className: className,
            methodName: methodName,
            threadName: Thread.current.name ?? "Thread-\(threadID)",
            threadID: threadID,
            callStack: Thread.callStackSymbols,
            isMainThread: Thread.isMainThread
        )

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.violations.insert(violation, at: 0)
            if self.violations.count > self.maxViolations {
                self.violations.removeLast()
            }
        }
    }

    // MARK: - Swizzling

    private func swizzleMethods() {
        // UIView methods that must run on main thread
        let viewSelectors: [(Selector, Selector)] = [
            (#selector(UIView.setNeedsLayout), #selector(UIView.phantom_setNeedsLayout)),
            (#selector(UIView.setNeedsDisplay as (UIView) -> () -> Void), #selector(UIView.phantom_setNeedsDisplay)),
            (#selector(UIView.layoutIfNeeded), #selector(UIView.phantom_layoutIfNeeded)),
        ]

        for (original, swizzled) in viewSelectors {
            PhantomSwizzler.swizzle(
                cls: UIView.self,
                originalSelector: original,
                swizzledSelector: swizzled
            )
        }
    }
}

// MARK: - Swizzled UIView Methods

extension UIView {

    @objc func phantom_setNeedsLayout() {
        if !Thread.isMainThread {
            PhantomMainThreadChecker.shared.recordViolation(
                className: String(describing: type(of: self)),
                methodName: "setNeedsLayout()"
            )
        }
        phantom_setNeedsLayout() // Calls original via swizzle
    }

    @objc func phantom_setNeedsDisplay() {
        if !Thread.isMainThread {
            PhantomMainThreadChecker.shared.recordViolation(
                className: String(describing: type(of: self)),
                methodName: "setNeedsDisplay()"
            )
        }
        phantom_setNeedsDisplay()
    }

    @objc func phantom_layoutIfNeeded() {
        if !Thread.isMainThread {
            PhantomMainThreadChecker.shared.recordViolation(
                className: String(describing: type(of: self)),
                methodName: "layoutIfNeeded()"
            )
        }
        phantom_layoutIfNeeded()
    }
}
#endif
