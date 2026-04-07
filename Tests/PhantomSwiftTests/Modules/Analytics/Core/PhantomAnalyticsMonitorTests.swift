import XCTest
@testable import PhantomSwift

final class PhantomAnalyticsMonitorTests: XCTestCase {

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        PhantomAnalyticsMonitor.shared.clear()
    }

    override func tearDown() {
        PhantomAnalyticsMonitor.shared.clear()
        super.tearDown()
    }

    // MARK: - Helper Classes

    class MockEventObserver: PhantomEventObserver {
        var receivedEvents: [PhantomEvent] = []
        let expectation: XCTestExpectation?

        init(expectation: XCTestExpectation? = nil) {
            self.expectation = expectation
        }

        func onEvent(_ event: PhantomEvent) {
            receivedEvents.append(event)
            if case .analyticsEvent = event {
                expectation?.fulfill()
            }
        }
    }

    // MARK: - Tests

    func testTrackEvent_AppendsToEvents() {
        let name = "TestEvent"
        let provider = "TestProvider"
        let parameters: [String: Any] = ["key": "value", "count": 1]

        PhantomAnalyticsMonitor.shared.track(name: name, provider: provider, parameters: parameters)

        let events = PhantomAnalyticsMonitor.shared.events
        XCTAssertEqual(events.count, 1)

        let trackedEvent = events.first
        XCTAssertEqual(trackedEvent?.name, name)
        XCTAssertEqual(trackedEvent?.provider, provider)
        XCTAssertEqual(trackedEvent?.parameters["key"] as? String, "value")
        XCTAssertEqual(trackedEvent?.parameters["count"] as? String, "1")
    }

    func testTrackEvent_RespectsMaxCapacity() {
        // Find the maximum capacity by adding events until the count stops increasing
        var maxObservedCount = 0

        // Add a large number of events to hit the capacity limit (likely 500)
        for i in 0..<1000 {
            PhantomAnalyticsMonitor.shared.track(name: "Event\(i)", parameters: [:])
            let currentCount = PhantomAnalyticsMonitor.shared.events.count
            if currentCount > maxObservedCount {
                maxObservedCount = currentCount
            }
        }

        let finalEvents = PhantomAnalyticsMonitor.shared.events
        XCTAssertTrue(finalEvents.count > 0, "Capacity should be greater than zero")
        XCTAssertEqual(finalEvents.count, maxObservedCount, "Count should max out at the capacity limit")

        // The last inserted element should be at the end
        XCTAssertEqual(finalEvents.last?.name, "Event999")
        // The first element should be exactly the capacity offset
        XCTAssertEqual(finalEvents.first?.name, "Event\(1000 - maxObservedCount)")
    }

    func testTrackEvent_PostsNotificationOnMainThread() {
        let expectation = XCTestExpectation(description: "phantomAnalyticsUpdated notification should be posted")

        var isMainThread = false

        let observer = NotificationCenter.default.addObserver(
            forName: .phantomAnalyticsUpdated,
            object: nil,
            queue: .main
        ) { _ in
            isMainThread = Thread.isMainThread
            expectation.fulfill()
        }

        PhantomAnalyticsMonitor.shared.track(name: "NotifyEvent", parameters: [:])

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(isMainThread, "Notification was not delivered on the main thread")
        NotificationCenter.default.removeObserver(observer)
    }

    func testTrackEvent_PostsToEventBus() {
        let expectation = XCTestExpectation(description: "Event bus should receive analyticsEvent")
        let mockObserver = MockEventObserver(expectation: expectation)

        PhantomEventBus.shared.subscribe(mockObserver, to: "analyticsEvent")

        PhantomAnalyticsMonitor.shared.track(
            name: "BusEvent",
            provider: "BusProvider",
            parameters: ["foo": "bar"]
        )

        wait(for: [expectation], timeout: 1.0)

        PhantomEventBus.shared.unsubscribe(mockObserver, from: "analyticsEvent")

        XCTAssertEqual(mockObserver.receivedEvents.count, 1)
        if case let .analyticsEvent(name, provider, parameters) = mockObserver.receivedEvents.first! {
            XCTAssertEqual(name, "BusEvent")
            XCTAssertEqual(provider, "BusProvider")
            XCTAssertEqual(parameters["foo"] as? String, "bar")
        } else {
            XCTFail("Expected .analyticsEvent but got something else")
        }
    }

    func testTrackEvent_DefaultProvider() {
        PhantomAnalyticsMonitor.shared.track(name: "DefaultProviderEvent", parameters: [:])

        let events = PhantomAnalyticsMonitor.shared.events
        XCTAssertEqual(events.first?.provider, "Internal")
    }
}
