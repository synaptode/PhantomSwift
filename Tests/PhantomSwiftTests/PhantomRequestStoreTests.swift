import XCTest
@testable import PhantomSwift

final class PhantomRequestStoreTests: XCTestCase {
    var store: PhantomRequestStore!

    override func setUp() {
        super.setUp()
        store = PhantomRequestStore.shared
        store.clear()
    }

    override func tearDown() {
        store.clear()
        PhantomEventBus.shared.unsubscribeAll(self)
        super.tearDown()
    }

    func testAddRequest() {
        let expectation = XCTestExpectation(description: "Wait for request to be added")
        let url = URL(string: "https://example.com")!
        let request = PhantomRequest(url: url, method: "GET", headers: [:], body: nil)

        // Use EventBus to synchronize instead of hardcoded delays
        class Observer: PhantomEventObserver {
            let exp: XCTestExpectation
            init(exp: XCTestExpectation) { self.exp = exp }
            func onEvent(_ event: PhantomEvent) {
                if case .networkRequestCaptured = event { exp.fulfill() }
            }
        }
        let observer = Observer(exp: expectation)
        PhantomEventBus.shared.subscribe(observer, to: "networkRequestCaptured")

        store.add(request)

        wait(for: [expectation], timeout: 1.0)

        let requests = store.getAll()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.id, request.id)
    }

    func testAddMultipleRequestsOrder() {
        let expectation = XCTestExpectation(description: "Wait for 2 requests")
        expectation.expectedFulfillmentCount = 2

        let url1 = URL(string: "https://example.com/1")!
        let request1 = PhantomRequest(url: url1, method: "GET", headers: [:], body: nil)

        let url2 = URL(string: "https://example.com/2")!
        let request2 = PhantomRequest(url: url2, method: "POST", headers: [:], body: nil)

        class Observer: PhantomEventObserver {
            let exp: XCTestExpectation
            init(exp: XCTestExpectation) { self.exp = exp }
            func onEvent(_ event: PhantomEvent) {
                if case .networkRequestCaptured = event { exp.fulfill() }
            }
        }
        let observer = Observer(exp: expectation)
        PhantomEventBus.shared.subscribe(observer, to: "networkRequestCaptured")

        store.add(request1)
        store.add(request2)

        wait(for: [expectation], timeout: 1.0)

        let requests = self.store.getAll()
        XCTAssertEqual(requests.count, 2)
        // Should be newest first
        XCTAssertEqual(requests[0].id, request2.id)
        XCTAssertEqual(requests[1].id, request1.id)
    }

    func testMaxCountLimit() {
        // Since we can't easily sync 1005 requests via EventBus without complexity,
        // we'll use a small delay but also verify the final count.
        // In a real scenario, we might want to expose a way to sync with the barrier queue.

        let totalToAdd = 1005
        for i in 0..<totalToAdd {
            let request = PhantomRequest(url: URL(string: "https://example.com/\(i)")!, method: "GET", headers: [:], body: nil)
            store.add(request)
        }

        let expectation = XCTestExpectation(description: "Wait for all requests to be processed")

        // Wait longer for 1000+ requests
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let requests = self.store.getAll()
            XCTAssertEqual(requests.count, 1000)
            // The first ones added should have been removed.
            // The newest one should be "https://example.com/1004"
            XCTAssertEqual(requests.first?.url.absoluteString, "https://example.com/1004")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testEventBusNotification() {
        class MockObserver: PhantomEventObserver {
            var capturedRequest: PhantomRequest?
            let expectation: XCTestExpectation

            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }

            func onEvent(_ event: PhantomEvent) {
                if case .networkRequestCaptured(let request) = event {
                    capturedRequest = request
                    expectation.fulfill()
                }
            }
        }

        let expectation = XCTestExpectation(description: "Wait for event bus notification")
        let observer = MockObserver(expectation: expectation)
        PhantomEventBus.shared.subscribe(observer, to: "networkRequestCaptured")

        let request = PhantomRequest(url: URL(string: "https://example.com")!, method: "GET", headers: [:], body: nil)
        store.add(request)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(observer.capturedRequest?.id, request.id)
    }

    func testUpdateRequest() {
        let expectation = XCTestExpectation(description: "Wait for request to be added")
        let url = URL(string: "https://example.com")!
        var request = PhantomRequest(url: url, method: "GET", headers: [:], body: nil)

        class Observer: PhantomEventObserver {
            let exp: XCTestExpectation
            init(exp: XCTestExpectation) { self.exp = exp }
            func onEvent(_ event: PhantomEvent) {
                if case .networkRequestCaptured = event { exp.fulfill() }
            }
        }
        let observer = Observer(exp: expectation)
        PhantomEventBus.shared.subscribe(observer, to: "networkRequestCaptured")

        store.add(request)
        wait(for: [expectation], timeout: 1.0)

        // Now modify the request and update it
        request.status = .completed
        store.update(request)

        // Fetch it back
        let requests = store.getAll()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.status, .completed)
    }

    func testConcurrentAdd() {
        let concurrentQueue = DispatchQueue(label: "com.test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let count = 100

        for i in 0..<count {
            group.enter()
            concurrentQueue.async {
                let request = PhantomRequest(
                    url: URL(string: "https://example.com/\(i)")!,
                    method: "GET",
                    headers: [:],
                    body: nil
                )
                self.store.add(request)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "Concurrent additions should not deadlock or timeout")

        // Wait a tiny bit for the barrier tasks to actually finish populating the store
        // since EventBus notifications and actual storage might be async
        let exp = XCTestExpectation(description: "Wait for barrier")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        let requests = store.getAll()
        XCTAssertEqual(requests.count, count)
    }
}

extension PhantomRequestStoreTests: PhantomEventObserver {
    func onEvent(_ event: PhantomEvent) {}
}
