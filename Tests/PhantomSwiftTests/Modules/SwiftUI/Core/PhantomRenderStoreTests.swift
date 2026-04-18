import XCTest
@testable import PhantomSwift

final class PhantomRenderStoreTests: XCTestCase {

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollInterval: TimeInterval = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        XCTFail("Condition was not met before timeout", file: file, line: line)
    }

    override func setUp() {
        super.setUp()
        PhantomRenderStore.shared.clear()
        PhantomRenderStore.shared.isPaused = false
        PhantomRenderStore.shared.isUIKitTrackingEnabled = false
    }

    override func tearDown() {
        PhantomRenderStore.shared.clear()
        super.tearDown()
    }

    func testTrackSwiftUIEvent() {
        let store = PhantomRenderStore.shared
        let uniqueViewName = "TestView-\(UUID().uuidString)"

        store.track(viewName: uniqueViewName, type: .swiftUI)

        waitUntil {
            store.getAll().contains(where: { $0.viewName == uniqueViewName })
        }

        let events = store.getAll()
        let event = events.first(where: { $0.viewName == uniqueViewName })

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .swiftUI)
        XCTAssertEqual(event?.count, 1)
    }

    func testTrackUIKitEventWhenDisabled() {
        let store = PhantomRenderStore.shared
        store.isUIKitTrackingEnabled = false
        let uniqueViewName = "TestUIKitView-\(UUID().uuidString)"

        store.track(viewName: uniqueViewName, type: .uiKit)

        let expectation = XCTestExpectation(description: "Track UIKit Event Disabled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let events = store.getAll()
            let event = events.first(where: { $0.viewName == uniqueViewName })

            XCTAssertNil(event)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTrackUIKitEventWhenEnabled() {
        let store = PhantomRenderStore.shared
        store.isUIKitTrackingEnabled = true
        let uniqueViewName = "TestUIKitView-\(UUID().uuidString)"

        store.track(viewName: uniqueViewName, type: .uiKit)

        waitUntil {
            store.getAll().contains(where: { $0.viewName == uniqueViewName })
        }

        let events = store.getAll()
        let event = events.first(where: { $0.viewName == uniqueViewName })

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .uiKit)
        XCTAssertEqual(event?.count, 1)
    }

    func testTrackWhenPaused() {
        let store = PhantomRenderStore.shared
        store.isPaused = true
        let uniqueViewName = "TestView-\(UUID().uuidString)"

        store.track(viewName: uniqueViewName)

        let expectation = XCTestExpectation(description: "Track Event Paused")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let events = store.getAll()
            let event = events.first(where: { $0.viewName == uniqueViewName })

            XCTAssertNil(event)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTrackMultipleEventsSameView() {
        let store = PhantomRenderStore.shared
        let uniqueViewName = "TestView-\(UUID().uuidString)"

        store.track(viewName: uniqueViewName)
        store.track(viewName: uniqueViewName)
        store.track(viewName: uniqueViewName)

        waitUntil {
            store.getAll().first(where: { $0.viewName == uniqueViewName })?.count == 3
        }

        let events = store.getAll()
        let event = events.first(where: { $0.viewName == uniqueViewName })

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.count, 3)
    }
}
