#if DEBUG
import Foundation
import CoreLocation

/// Manages GPS spoofing and mock locations for PhantomSwift.
public final class PhantomLocationManager {
    public static let shared = PhantomLocationManager()
    
    /// The currently selected mock location. Persists across sessions.
    public private(set) var selectedLocation: PhantomLocation? {
        didSet {
            if let loc = selectedLocation {
                UserDefaults.standard.set(loc.name, forKey: "PhantomMockLocationName")
            } else {
                UserDefaults.standard.removeObject(forKey: "PhantomMockLocationName")
            }
            NotificationCenter.default.post(name: .phantomLocationChanged, object: selectedLocation)
        }
    }
    
    private init() {
        if let savedName = UserDefaults.standard.string(forKey: "PhantomMockLocationName") {
            self.selectedLocation = mockLocations.first(where: { $0.name == savedName })
        }
    }
    
    /// Predefined mock locations for testing.
    public let mockLocations: [PhantomLocation] = [
        PhantomLocation(name: "Apple Park (Cupertino)", latitude: 37.3349, longitude: -122.0090),
        PhantomLocation(name: "London (Big Ben)", latitude: 51.5007, longitude: -0.1246),
        PhantomLocation(name: "Tokyo (Shibuya)", latitude: 35.6580, longitude: 139.7016),
        PhantomLocation(name: "Jakarta (Monas)", latitude: -6.1754, longitude: 106.8272),
        PhantomLocation(name: "Sydney (Opera House)", latitude: -33.8568, longitude: 151.2153)
    ]
    
    /// Sets the active mock location.
    public func selectLocation(_ location: PhantomLocation?) {
        self.selectedLocation = location
    }
}

/// Notification names for Environment changes.
extension NSNotification.Name {
    public static let phantomLocationChanged = NSNotification.Name("PhantomLocationChanged")
    public static let phantomSystemStateChanged = NSNotification.Name("PhantomSystemStateChanged")
}

/// Represents a location for spoofing.
public struct PhantomLocation: Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    
    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public static func == (lhs: PhantomLocation, rhs: PhantomLocation) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
#endif
