#if DEBUG
import Foundation
import PhantomSwiftNetworking

/// Thread-safe storage for captured network requests.
public final class PhantomRequestStore {
    public static let shared = PhantomRequestStore()

    private let queue = DispatchQueue(label: "com.phantomswift.network.store", attributes: .concurrent)
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    // Ring buffer keeps insert/update O(1) while preserving a bounded history.
    private var buffer: [PhantomRequest?]
    private var head = 0
    private var count = 0
    /// O(1) lookup: request.id → buffer slot.
    private var indexMap: [UUID: Int] = [:]
    private let maxCount = 1000

    private init() {
        self.buffer = Array(repeating: nil, count: maxCount)
        queue.setSpecific(key: queueSpecificKey, value: ())
    }

    /// Adds a new request. O(1) amortized.
    public func add(_ request: PhantomRequest) {
        queue.async(flags: .barrier) {
            if self.count < self.maxCount {
                let slot = (self.head + self.count) % self.maxCount
                self.buffer[slot] = request
                self.indexMap[request.id] = slot
                self.count += 1
            } else {
                let slot = self.head
                if let removed = self.buffer[slot] {
                    self.indexMap.removeValue(forKey: removed.id)
                }
                self.buffer[slot] = request
                self.indexMap[request.id] = slot
                self.head = (self.head + 1) % self.maxCount
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
            guard let slot = self.indexMap[request.id] else { return }
            self.buffer[slot] = request
        }
    }

    /// Returns all captured requests (newest first).
    public func getAll() -> [PhantomRequest] {
        queue.sync {
            var result: [PhantomRequest] = []
            result.reserveCapacity(count)
            for offset in 0..<count {
                let slot = (head + offset) % maxCount
                if let entry = buffer[slot] {
                    result.append(entry)
                }
            }
            return Array(result.reversed())
        }
    }

    /// Clears all captured requests.
    public func clear() {
        if DispatchQueue.getSpecific(key: queueSpecificKey) != nil {
            buffer = Array(repeating: nil, count: maxCount)
            head = 0
            count = 0
            indexMap.removeAll()
            return
        }

        queue.sync(flags: .barrier) {
            self.buffer = Array(repeating: nil, count: self.maxCount)
            self.head = 0
            self.count = 0
            self.indexMap.removeAll()
        }
    }
}
#endif
