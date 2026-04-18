import XCTest
@testable import PhantomSwift

final class PhantomAnalyticsMonitorQueryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhantomAnalyticsMonitor.shared.clear()
    }

    override func tearDown() {
        PhantomAnalyticsMonitor.shared.clear()
        super.tearDown()
    }

    func testEventsForProvider() {
        let monitor = PhantomAnalyticsMonitor.shared

        monitor.track(name: "login", provider: "Firebase", parameters: [:])
        monitor.track(name: "purchase", provider: "Amplitude", parameters: [:])
        monitor.track(name: "logout", provider: "Firebase", parameters: [:])

        let firebaseEvents = monitor.events(for: "Firebase")
        XCTAssertEqual(firebaseEvents.count, 2)
        XCTAssertEqual(firebaseEvents[0].name, "logout")
        XCTAssertEqual(firebaseEvents[1].name, "login")

        let amplitudeEvents = monitor.events(for: "Amplitude")
        XCTAssertEqual(amplitudeEvents.count, 1)
        XCTAssertEqual(amplitudeEvents[0].name, "purchase")

        let allEvents = monitor.events(for: nil)
        XCTAssertEqual(allEvents.count, 3)
        XCTAssertEqual(allEvents[0].name, "logout")
        XCTAssertEqual(allEvents[1].name, "purchase")
        XCTAssertEqual(allEvents[2].name, "login")

        let unknownEvents = monitor.events(for: "Unknown")
        XCTAssertTrue(unknownEvents.isEmpty)
    }
}
