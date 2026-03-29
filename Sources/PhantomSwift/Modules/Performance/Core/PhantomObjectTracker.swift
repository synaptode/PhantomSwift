#if DEBUG
import Foundation

/// Represents a tracked object in memory.
public struct PhantomTrackedObject: Identifiable {
    public let id: String
    public let className: String
    public let address: String
    public weak var object: AnyObject?
    public let timestamp: Date
    public let file: String
    public let line: Int
    
    public var isAlive: Bool { object != nil }
}

/// A "Watcher" object that notifies when the parent object is deallocated.
private final class DeallocWatcher {
    let onDeinit: () -> Void
    init(onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

/// Monitors object lifecycles to find retain cycles and leaks.
private var phantomWatcherKey: UInt8 = 0

public final class PhantomObjectTracker {
    public static let shared = PhantomObjectTracker()
    
    public private(set) var trackedObjects: [PhantomTrackedObject] = []
    private var watchers: [String: Any] = [:]
    
    private init() {}
    
    /// Starts tracking an object.
    public func track(_ object: AnyObject, name: String? = nil, file: String = #file, line: Int = #line) {
        let address = String(format: "%p", unsafeBitCast(object, to: Int.self))
        let className = name ?? String(describing: type(of: object))
        let id = "\(className)_\(address)"
        
        // Extract filename from path
        let fileName = (file as NSString).lastPathComponent
        
        let tracked = PhantomTrackedObject(
            id: id,
            className: className,
            address: address,
            object: object,
            timestamp: Date(),
            file: fileName,
            line: line
        )
        
        DispatchQueue.main.async {
            self.trackedObjects.append(tracked)
            
            // Attach a watcher to detect deallocation
            let watcher = DeallocWatcher { [weak self] in
                print("♻️ [PhantomSwift] Deallocated: \(className) (\(address))")
                self?.objectDidDeallocate(id: id)
            }
            
            // Use a unique but consistent key for the association
            objc_setAssociatedObject(object, &phantomWatcherKey, watcher, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func objectDidDeallocate(id: String) {
        DispatchQueue.main.async {
            // Entry stays but object reference becomes nil.
        }
    }
    
    /// Removes objects that have been deallocated from the tracking list.
    public func clearDeallocated() {
        DispatchQueue.main.async {
            self.trackedObjects.removeAll { !$0.isAlive }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
public extension View {
    func phantomTrackMemory(_ name: String? = nil) -> some View {
        self.onAppear {
            // Tracking the underlying UIViewController or State if possible
            // For now, we provide a manual hook via PhantomObjectTracker.shared.track()
        }
    }
}
#endif
#endif
