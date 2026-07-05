#if DEBUG
import UIKit
import Foundation

/// Represents a detected UI freeze/hang.
public struct PhantomHangEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let duration: TimeInterval
    public let screenName: String
    public let callStack: [String]
}

/// Watchdog that monitors the main thread for hangs.
public final class PhantomHangDetector {
    public static let shared = PhantomHangDetector()
    
    private let lock = NSLock()
    private var _hangs: [PhantomHangEvent] = []
    public var hangs: [PhantomHangEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _hangs
    }

    private var isStarted = false
    private let stateLock = NSLock()
    private let monitorQueue = DispatchQueue(label: "com.phantomswift.hang.detector", qos: .utility)
    private var monitorTimer: DispatchSourceTimer?
    private let threshold: TimeInterval = 0.4 // 400ms (Professional threshold)
    
    private init() {}
    
    public func start() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isStarted else { return }
        isStarted = true

        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.5, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard self.shouldContinueMonitoring else { return }
            self.checkMainThreadHang()
        }
        monitorTimer = timer
        timer.resume()
    }

    private var shouldContinueMonitoring: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isStarted
    }
    
    private func checkMainThreadHang() {
        let semaphore = DispatchSemaphore(value: 0)
        let start = Date()

        DispatchQueue.main.async {
            semaphore.signal()
        }

        // Wait for main thread to catch up
        let result = semaphore.wait(timeout: .now() + self.threshold + 0.1)

        if result == .timedOut {
            let end = Date()
            let duration = end.timeIntervalSince(start)
            recordHang(start: start, duration: duration)
        }
    }

    private func recordHang(start: Date, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Capture it NOW on the main thread after it recovers.
            // This usually still points to the end of the causing operation.
            let stack = Thread.callStackSymbols

            let topVC = PhantomPresentationResolver.activeHostWindow()?.rootViewController?.topMost
            let screenName = topVC?.className ?? "Unknown"

            let event = PhantomHangEvent(
                timestamp: start,
                duration: duration,
                screenName: screenName,
                callStack: stack
            )
            self.lock.lock()
            self._hangs.append(event)
            self.lock.unlock()

            NotificationCenter.default.post(name: NSNotification.Name("PhantomHangDetected"), object: nil)
            print("⚠️ [PhantomSwift] Main thread hang detected in \(screenName): \(String(format: "%.2f", duration))s")
        }
    }

    public func stop() {
        stateLock.lock()
        isStarted = false
        monitorTimer?.cancel()
        monitorTimer = nil
        stateLock.unlock()
    }
    
    public func clearLogs() {
        lock.lock()
        self._hangs.removeAll()
        lock.unlock()
        NotificationCenter.default.post(name: NSNotification.Name("PhantomHangDetected"), object: nil)
    }
}
#endif
