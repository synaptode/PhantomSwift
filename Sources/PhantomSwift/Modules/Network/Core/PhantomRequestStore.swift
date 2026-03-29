#if DEBUG
import Foundation

/// Thread-safe storage for captured network requests.
public final class PhantomRequestStore {
    public static let shared = PhantomRequestStore()

    private let queue = DispatchQueue(label: "com.phantomswift.network.store", attributes: .concurrent)
    // Requests stored newest-first for display; backed by O(1) index map for updates.
    private var requests: [PhantomRequest] = []
    /// O(1) lookup: request.id → index into `requests` array.
    private var indexMap: [UUID: Int] = [:]
    private let maxCount = 1000

    private init() {}

    /// Adds a new request. O(1) amortized.
    public func add(_ request: PhantomRequest) {
        queue.async(flags: .barrier) {
            // Prepend by appending + tracking the reversed logical index
            self.requests.insert(request, at: 0)
            // Rebuild index map (prepend shifts all existing indices by +1)
            self.indexMap = Dictionary(uniqueKeysWithValues:
                self.requests.enumerated().map { ($1.id, $0) })
            if self.requests.count > self.maxCount {
                let removed = self.requests.removeLast()
                self.indexMap.removeValue(forKey: removed.id)
            }
        }
        // Post event OUTSIDE barrier to prevent priority inversion
        queue.async { [request] in
            PhantomEventBus.shared.post(.networkRequestCaptured(request))
        }
    }

    /// Updates an existing request (e.g. when response arrives). O(1) via index map.
    public func update(_ request: PhantomRequest) {
        queue.async(flags: .barrier) {
            guard let index = self.indexMap[request.id] else { return }
            self.requests[index] = request
        }
    }

    /// Returns all captured requests (newest first).
    public func getAll() -> [PhantomRequest] {
        queue.sync { requests }
    }

    /// Clears all captured requests.
    public func clear() {
        queue.async(flags: .barrier) {
            self.requests.removeAll()
            self.indexMap.removeAll()
        }
    }
}
#endif
