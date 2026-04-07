import XCTest
@testable import PhantomSwift

final class PhantomLocationManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset state before each test
        PhantomLocationManager.shared.selectLocation(nil)
        UserDefaults.standard.removeObject(forKey: "PhantomMockLocationName")
    }

    override func tearDown() {
        // Reset state after each test
        PhantomLocationManager.shared.selectLocation(nil)
        UserDefaults.standard.removeObject(forKey: "PhantomMockLocationName")
        super.tearDown()
    }

    func testSelectLocation_WithValidLocation_UpdatesStateAndPostsNotification() {
        let manager = PhantomLocationManager.shared
        let location = PhantomLocation(name: "Test Location", latitude: 12.34, longitude: 56.78)

        let expectation = XCTestExpectation(description: "Wait for phantomLocationChanged notification")

        let token = NotificationCenter.default.addObserver(forName: .phantomLocationChanged, object: nil, queue: nil) { notification in
            if let obj = notification.object as? PhantomLocation {
                XCTAssertEqual(obj.name, location.name)
                XCTAssertEqual(obj.latitude, location.latitude)
                XCTAssertEqual(obj.longitude, location.longitude)
                expectation.fulfill()
            }
        }

        manager.selectLocation(location)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(manager.selectedLocation?.name, location.name)
        XCTAssertEqual(manager.selectedLocation?.latitude, location.latitude)
        XCTAssertEqual(manager.selectedLocation?.longitude, location.longitude)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "PhantomMockLocationName"), location.name)

        NotificationCenter.default.removeObserver(token)
    }

    func testSelectLocation_WithNil_ClearsStateAndPostsNotification() {
        let manager = PhantomLocationManager.shared
        // First set a location
        let location = PhantomLocation(name: "Initial Location", latitude: 1.0, longitude: 1.0)
        manager.selectLocation(location)
        XCTAssertNotNil(manager.selectedLocation)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "PhantomMockLocationName"))

        let expectation = XCTestExpectation(description: "Wait for phantomLocationChanged notification")

        let token = NotificationCenter.default.addObserver(forName: .phantomLocationChanged, object: nil, queue: nil) { notification in
            XCTAssertNil(notification.object)
            expectation.fulfill()
        }

        // Then clear it
        manager.selectLocation(nil)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertNil(manager.selectedLocation)
        XCTAssertNil(UserDefaults.standard.string(forKey: "PhantomMockLocationName"))

        NotificationCenter.default.removeObserver(token)
    }
}
