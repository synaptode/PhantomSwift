#if DEBUG
import Foundation

/// Represents a saved application state snapshot.
public struct PhantomSnapshot: Codable, Identifiable {
    public let id: String
    public let name: String
    public let timestamp: Date
    public let userDefaults: [String: String] // Simple string representation for now
    
    public init(id: String = UUID().uuidString, name: String, timestamp: Date = Date(), userDefaults: [String: String]) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.userDefaults = userDefaults
    }
}

/// Manages the archival and restoration of application state.
public final class PhantomSnapshotManager {
    public static let shared = PhantomSnapshotManager()
    
    private let snapshotsKey = "com.phantomswift.snapshots"
    
    private init() {}
    
    /// Saves the current state as a snapshot.
    public func saveCurrentState(name: String) -> PhantomSnapshot {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        var stringDefaults: [String: String] = [:]
        
        // Filter and stringify defaults for simpler storage
        for (key, value) in defaults {
            stringDefaults[key] = "\(value)"
        }
        
        let snapshot = PhantomSnapshot(name: name, userDefaults: stringDefaults)
        var saved = getAllSnapshots()
        saved.append(snapshot)
        
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: snapshotsKey)
        }
        
        return snapshot
    }
    
    /// Restores the app state from a snapshot.
    public func restore(snapshot: PhantomSnapshot) {
        // Restore UserDefaults
        for (key, value) in snapshot.userDefaults {
            // Attempt to recover types
            if let intVal = Int(value) {
                UserDefaults.standard.set(intVal, forKey: key)
            } else if value.lowercased() == "true" {
                UserDefaults.standard.set(true, forKey: key)
            } else if value.lowercased() == "false" {
                UserDefaults.standard.set(false, forKey: key)
            } else {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        
        UserDefaults.standard.synchronize()
        print("✅ [PhantomSwift] State restored from: \(snapshot.name)")
    }
    
    public func getAllSnapshots() -> [PhantomSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: snapshotsKey),
              let snapshots = try? JSONDecoder().decode([PhantomSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }
    
    public func delete(id: String) {
        var snapshots = getAllSnapshots()
        snapshots.removeAll(where: { $0.id == id })
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: snapshotsKey)
        }
    }
}
#endif
