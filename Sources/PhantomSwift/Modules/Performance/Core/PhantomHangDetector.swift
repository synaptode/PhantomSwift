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
    
    public private(set) var hangs: [PhantomHangEvent] = []
    
    private var isStarted = false
    private let threshold: TimeInterval = 0.4 // 400ms (Professional threshold)
    
    private init() {}
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        Thread.detachNewThread { [weak self] in
            guard let self = self else { return }
            
            while self.isStarted {
                self.checkMainThreadHang()
            }
        }
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

        // Frequency of checks
        Thread.sleep(forTimeInterval: 0.1)
    }

    private func recordHang(start: Date, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Capture it NOW on the main thread after it recovers.
            // This usually still points to the end of the causing operation.
            let stack = Thread.callStackSymbols

            let topVC = UIApplication.shared.keyWindow?.rootViewController?.topMost
            let screenName = topVC?.className ?? "Unknown"

            let event = PhantomHangEvent(
                timestamp: start,
                duration: duration,
                screenName: screenName,
                callStack: stack
            )
            self.hangs.append(event)

            NotificationCenter.default.post(name: NSNotification.Name("PhantomHangDetected"), object: nil)
            print("⚠️ [PhantomSwift] Main thread hang detected in \(screenName): \(String(format: "%.2f", duration))s")
        }
    }

    public func stop() {
        isStarted = false
    }
    
    public func clearLogs() {
        self.hangs.removeAll()
        NotificationCenter.default.post(name: NSNotification.Name("PhantomHangDetected"), object: nil)
    }
}
#endif
