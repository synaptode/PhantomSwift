#if DEBUG
import Foundation
import UIKit

/// Represents an analytics event (Firebase, Amplitude, etc.).
public struct PhantomAnalyticsEvent: Codable, Identifiable {
    public let id: String
    public let name: String
    public let provider: String
    public let parameters: [String: String]
    public let timestamp: Date

    public init(name: String, provider: String = "Generic", parameters: [String: Any]) {
        self.id   = UUID().uuidString
        self.name = name
        self.provider  = provider
        self.timestamp = Date()
        var stringParams: [String: String] = [:]
        for (key, value) in parameters { stringParams[key] = "\(value)" }
        self.parameters = stringParams
    }
}

/// Central bus for intercepting analytics events.
public final class PhantomAnalyticsMonitor {
    public static let shared = PhantomAnalyticsMonitor()

    private let lock = NSLock()
    private var _events: [PhantomAnalyticsEvent] = []
    private let maxCapacity = 500

    private init() {}

    /// All captured events (most recent last).
    public var events: [PhantomAnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    /// Distinct provider names, sorted alphabetically.
    public func allProviders() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(Set(_events.map { $0.provider })).sorted()
    }

    /// Events for a specific provider (nil = all), most recent first.
    public func events(for provider: String?) -> [PhantomAnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        let src = _events.reversed() as [PhantomAnalyticsEvent]
        guard let p = provider else { return src }
        return src.filter { $0.provider == p }
    }

    /// Dictionary of event name → occurrence count.
    public func frequencyMap() -> [String: Int] {
        lock.lock(); defer { lock.unlock() }
        return _events.reduce(into: [:]) { acc, e in acc[e.name, default: 0] += 1 }
    }

    /// Clear all stored events.
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        _events.removeAll()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .phantomAnalyticsUpdated, object: nil)
        }
    }

    /// Tracks an event manually. Call this from your Analytics SDK wrappers.
    public func track(name: String, provider: String = "Internal", parameters: [String: Any]) {
        let event = PhantomAnalyticsEvent(name: name, provider: provider, parameters: parameters)
        lock.lock()
        _events.append(event)
        if _events.count > maxCapacity { _events.removeFirst(_events.count - maxCapacity) }
        lock.unlock()

        DispatchQueue.main.async {
            PhantomEventBus.shared.post(.analyticsEvent(event.name, event.provider, event.parameters))
            NotificationCenter.default.post(name: .phantomAnalyticsUpdated, object: nil)
        }
    }
}

extension Notification.Name {
    static let phantomAnalyticsUpdated = Notification.Name("PhantomAnalyticsUpdated")
}

// MARK: - Stable per-provider accent colors

extension PhantomAnalyticsMonitor {
    /// Returns a consistent accent color for a given provider string.
    public static func color(for provider: String) -> UIColor {
        let palette: [UIColor] = [
            UIColor.Phantom.neonAzure,
            UIColor.Phantom.vibrantGreen,
            UIColor.Phantom.vibrantOrange,
            UIColor.Phantom.vibrantPurple,
            UIColor.Phantom.electricIndigo,
            UIColor.Phantom.vibrantRed,
        ]
        let index = abs(provider.hashValue) % palette.count
        return palette[index]
    }
}
#endif
