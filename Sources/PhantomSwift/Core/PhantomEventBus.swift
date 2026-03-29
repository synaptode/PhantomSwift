#if DEBUG
import Foundation

/// Internal event bus for cross-module communication.
public final class PhantomEventBus {
    public static let shared = PhantomEventBus()
    private let queue = DispatchQueue(label: "com.phantomswift.eventbus", attributes: .concurrent)
    private var observers: [String: [WeakObserver]] = [:]

    private init() {}

    /// Posts an event to all registered live observers, compacting dead entries.
    public func post(_ event: PhantomEvent) {
        let key = event.name
        queue.async(flags: .barrier) {
            // Compact dead weak references while we hold the write lock
            let live = (self.observers[key] ?? []).filter { $0.value != nil }
            self.observers[key] = live
            // Snapshot for notification (avoids holding lock during main dispatch)
            let snapshot = live.compactMap { $0.value }
            DispatchQueue.main.async {
                for observer in snapshot {
                    observer.onEvent(event)
                }
            }
        }
    }

    /// Subscribes an observer to a specific event type. Duplicate subscriptions are ignored.
    public func subscribe(_ observer: PhantomEventObserver, to eventType: String) {
        queue.async(flags: .barrier) {
            var current = self.observers[eventType] ?? []
            // Deduplicate: skip if already subscribed
            guard !current.contains(where: { $0.value === observer }) else { return }
            current.append(WeakObserver(value: observer))
            self.observers[eventType] = current
        }
    }

    /// Unsubscribes an observer from a specific event type.
    public func unsubscribe(_ observer: PhantomEventObserver, from eventType: String) {
        queue.async(flags: .barrier) {
            self.observers[eventType]?.removeAll { $0.value == nil || $0.value === observer }
        }
    }

    /// Unsubscribes an observer from all event types.
    public func unsubscribeAll(_ observer: PhantomEventObserver) {
        queue.async(flags: .barrier) {
            for key in self.observers.keys {
                self.observers[key]?.removeAll { $0.value == nil || $0.value === observer }
            }
        }
    }
}

/// Protocol for objects that want to observe PhantomSwift events.
public protocol PhantomEventObserver: AnyObject {
    func onEvent(_ event: PhantomEvent)
}

/// Internal wrapper for weak observer references.
private struct WeakObserver {
    weak var value: PhantomEventObserver?
}

/// Defines internal events passed through the event bus.
public enum PhantomEvent {
    case appLaunched
    case dashboardPresented
    case dashboardDismissed
    case logAdded(LogEntry)
    case networkRequestCaptured(PhantomRequest)
    case memoryLeakDetected(LeakReport)
    case analyticsEvent(String, String, [String: String])
    case log(String)
    
    /// Returns a stable string identifier for the event type.
    internal var name: String {
        switch self {
        case .appLaunched: return "appLaunched"
        case .dashboardPresented: return "dashboardPresented"
        case .dashboardDismissed: return "dashboardDismissed"
        case .logAdded: return "logAdded"
        case .networkRequestCaptured: return "networkRequestCaptured"
        case .memoryLeakDetected: return "memoryLeakDetected"
        case .analyticsEvent: return "analyticsEvent"
        case .log: return "log"
        }
    }
}
#endif
