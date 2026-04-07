import XCTest
@testable import PhantomSwift

class MockEventObserver: PhantomEventObserver {
    var receivedEvents: [PhantomEvent] = []
    var onEventReceived: (() -> Void)?

    func onEvent(_ event: PhantomEvent) {
        receivedEvents.append(event)
        onEventReceived?()
    }
}

final class PhantomEventBusTests: XCTestCase {
    var eventBus: PhantomEventBus!

    override func setUp() {
        super.setUp()
        eventBus = PhantomEventBus.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    func testPostEventSingleObserver() {
        let observer = MockEventObserver()
        let expectation = self.expectation(description: "Event received")

        let uniqueLog = UUID().uuidString
        let eventType = PhantomEvent.log(uniqueLog).name

        observer.onEventReceived = {
            expectation.fulfill()
        }

        eventBus.subscribe(observer, to: eventType)
        eventBus.post(.log(uniqueLog))

        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertEqual(observer.receivedEvents.count, 1)
            if let firstEvent = observer.receivedEvents.first, case .log(let message) = firstEvent {
                XCTAssertEqual(message, uniqueLog)
            } else {
                XCTFail("Expected .log event with message \(uniqueLog)")
            }
        }

        eventBus.unsubscribeAll(observer)
    }

    func testPostEventMultipleObservers() {
        let observer1 = MockEventObserver()
        let observer2 = MockEventObserver()

        let uniqueLog = UUID().uuidString
        let eventType = PhantomEvent.log(uniqueLog).name

        let expectation1 = self.expectation(description: "Observer 1 received")
        let expectation2 = self.expectation(description: "Observer 2 received")

        observer1.onEventReceived = { expectation1.fulfill() }
        observer2.onEventReceived = { expectation2.fulfill() }

        eventBus.subscribe(observer1, to: eventType)
        eventBus.subscribe(observer2, to: eventType)

        eventBus.post(.log(uniqueLog))

        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertEqual(observer1.receivedEvents.count, 1)
            XCTAssertEqual(observer2.receivedEvents.count, 1)

            if let firstEvent = observer1.receivedEvents.first, case .log(let message) = firstEvent {
                XCTAssertEqual(message, uniqueLog)
            } else {
                XCTFail("Expected .log event with message \(uniqueLog)")
            }
        }

        eventBus.unsubscribeAll(observer1)
        eventBus.unsubscribeAll(observer2)
    }

    func testPostCompactsDeadWeakReferences() {
        var observer: MockEventObserver? = MockEventObserver()
        let expectation = self.expectation(description: "Should not receive event")
        expectation.isInverted = true

        let uniqueLog = UUID().uuidString
        let eventType = PhantomEvent.log(uniqueLog).name

        observer?.onEventReceived = {
            expectation.fulfill()
        }

        eventBus.subscribe(observer!, to: eventType)

        // Deallocate the observer
        observer = nil

        // Post the event. This should compact the dead reference.
        eventBus.post(.log(uniqueLog))

        // Wait a short bit to ensure the async callback doesn't happen
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testThreadSafetyDuringPost() {
        let observer = MockEventObserver()
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.phantomswift.test.concurrent", attributes: .concurrent)

        let uniqueLogBase = UUID().uuidString

        // Multiple subscribes and posts concurrently
        for i in 0..<100 {
            dispatchGroup.enter()
            concurrentQueue.async {
                let event = PhantomEvent.log("\(uniqueLogBase)-\(i)")
                self.eventBus.subscribe(observer, to: event.name)
                self.eventBus.post(event)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()

        // Since main queue dispatches happen asynchronously in post,
        // wait for main queue to finish processing.
        let exp = expectation(description: "Wait for main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        // Count should be equal to the number of posts
        // Wait, multiple posts of same event type might trigger the observer multiple times.
        // Actually, they all share `PhantomEvent.log.name` which is always "log".
        // So observer is subscribed to "log" 100 times (though deduplicated).
        // The event bus deduplicates by object identity.
        // And we post 100 times. So we should get 100 events.
        XCTAssertEqual(observer.receivedEvents.count, 100)

        eventBus.unsubscribeAll(observer)
    }
}
