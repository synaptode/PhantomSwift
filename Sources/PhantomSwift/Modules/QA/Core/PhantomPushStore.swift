#if DEBUG
import Foundation

/// Thread-safe in-memory storage for captured live push and local notifications.
public final class PhantomPushStore {
    public static let shared = PhantomPushStore()

    private let queue = DispatchQueue(label: "com.phantomswift.push.store", attributes: .concurrent)
    private var records: [PhantomPushRecord] = []
    private let maxRecords = 500
    private let apnsTokenDefaultsKey = "com.phantomswift.push.apnsToken"

    private var _apnsToken: String?

    public var apnsToken: String? {
        queue.sync { _apnsToken }
    }

    private init() {
        self._apnsToken = UserDefaults.standard.string(forKey: apnsTokenDefaultsKey)
    }

    /// Number of captured notifications in store.
    public var count: Int {
        queue.sync { records.count }
    }

    /// Stores a captured notification and notifies observers.
    public func add(_ record: PhantomPushRecord) {
        queue.async(flags: .barrier) {
            self.records.insert(record, at: 0)
            if self.records.count > self.maxRecords {
                self.records.removeLast()
            }
        }

        queue.async {
            PhantomEventBus.shared.post(.pushNotificationCaptured(record))
        }
    }

    /// Returns all captured notification records (newest first).
    public func getAll() -> [PhantomPushRecord] {
        queue.sync { records }
    }

    /// Clears all recorded notifications.
    public func clear() {
        queue.async(flags: .barrier) {
            self.records.removeAll()
        }
    }

    /// Saves the device's APNs token string and posts an event.
    public func setDeviceToken(_ token: String) {
        queue.async(flags: .barrier) {
            self._apnsToken = token
            UserDefaults.standard.set(token, forKey: self.apnsTokenDefaultsKey)
        }

        queue.async {
            PhantomEventBus.shared.post(.apnsTokenUpdated(token))
        }
    }
}
#endif
