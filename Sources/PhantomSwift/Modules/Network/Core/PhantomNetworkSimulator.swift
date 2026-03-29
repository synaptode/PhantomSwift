#if DEBUG
import Foundation

/// Simulates various network conditions like latency and packet loss.
public final class PhantomNetworkSimulator {
    public static let shared = PhantomNetworkSimulator()
    public static let stateChangedNotification = Notification.Name("com.phantomswift.network.simulator.stateChanged")
    
    public var isEnabled: Bool = false {
        didSet { notifyStateChanged() }
    }
    public var latency: TimeInterval = 0 { // Seconds
        didSet { notifyStateChanged() }
    }
    public var errorRate: Double = 0 { // 0.0 to 1.0
        didSet { notifyStateChanged() }
    }
    
    private func notifyStateChanged() {
        NotificationCenter.default.post(name: Self.stateChangedNotification, object: self)
    }
    
    private init() {}
    
    /// Applies simulated conditions to a request.
    /// Returns an error if simulation dictates failure.
    public func process(completion: @escaping (Error?) -> Void) {
        guard isEnabled else {
            completion(nil)
            return
        }
        
        // 1. Simulate Error
        if Double.random(in: 0...1) < errorRate {
            let error = NSError(domain: "com.phantomswift.simulator", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Simulated Network Timeout"])
            completion(error)
            return
        }
        
        // 2. Simulate Latency
        if latency > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + latency) {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}
#endif
