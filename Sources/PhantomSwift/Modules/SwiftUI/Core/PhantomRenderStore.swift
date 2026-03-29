#if DEBUG
import Foundation
import SwiftUI

/// Defines the type of UI event being tracked.
public enum PhantomRenderEventType: String {
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
}

/// Represents a single render or layout event.
public struct PhantomRenderEvent: Identifiable {
    public let id = UUID()
    public let viewName: String
    public let type: PhantomRenderEventType
    public let timestamp = Date()
    public var count: Int
}

/// Stores and manages SwiftUI render events.
public final class PhantomRenderStore {
    public static let shared = PhantomRenderStore()
    
    private(set) var events: [String: PhantomRenderEvent] = [:]
    private let queue = DispatchQueue(label: "com.phantomswift.ui.store", attributes: .concurrent)
    
    public var isUIKitTrackingEnabled = false
    public var isPaused = false
    
    private init() {}
    
    /// Tracks a render or layout update.
    public func track(viewName: String, type: PhantomRenderEventType = .swiftUI) {
        guard !isPaused else { return }
        if type == .uiKit && !isUIKitTrackingEnabled { return }
        
        queue.async(flags: .barrier) {
            let key = "\(type.rawValue)-\(viewName)"
            var current = self.events[key] ?? PhantomRenderEvent(viewName: viewName, type: type, count: 0)
            current.count += 1
            self.events[key] = current
            
            // Only log high-frequency updates occasionally to avoid flooding the bus
            if current.count % 5 == 0 || current.count == 1 {
                PhantomEventBus.shared.post(.log("[\(type.rawValue)] Rendered: \(viewName) (Total: \(current.count))"))
            }
        }
    }
    
    public func getAll() -> [PhantomRenderEvent] {
        return queue.sync {
            Array(events.values).sorted(by: { $0.count > $1.count })
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.events.removeAll()
        }
    }
}
#endif
