import XCTest
@testable import PhantomSwift

final class PhantomRequestStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean state before each test
        PhantomRequestStore.shared.clear()
    }

    override func tearDown() {
        // Clean up after test
        PhantomRequestStore.shared.clear()
        super.tearDown()
    }

    func testClearRequests() {
        // 1. Setup - Create and add some requests
        let store = PhantomRequestStore.shared

        guard let url1 = URL(string: "https://example.com/api/v1/users"),
              let url2 = URL(string: "https://example.com/api/v1/settings") else {
            XCTFail("Failed to create URLs")
            return
        }

        let request1 = PhantomRequest(id: UUID(), url: url1, method: "GET", headers: [:], body: nil)
        let request2 = PhantomRequest(id: UUID(), url: url2, method: "POST", headers: [:], body: nil)

        store.add(request1)
        store.add(request2)

        // Because add() and clear() use async barrier blocks and getAll() uses sync blocks on the same concurrent queue,
        // getAll() inherently waits for the preceding operations to finish.
        let requestsBeforeClear = store.getAll()
        XCTAssertEqual(requestsBeforeClear.count, 2, "Store should contain 2 requests before clear")

        // 2. Action - Clear the store
        store.clear()

        // 3. Verify - Check requests are removed
        let requestsAfterClear = store.getAll()
        XCTAssertTrue(requestsAfterClear.isEmpty, "Store should be empty after clear")

        // 4. Verify indexMap is also cleared by trying to update an old request.
        // If indexMap wasn't cleared but `requests` array was, this would crash because it would access an out-of-bounds index
        // or access a cleared array based on a stale index.
        var updatedRequest1 = request1
        updatedRequest1.status = .completed
        store.update(updatedRequest1)

        // Calling getAll() will sync with the queue, ensuring the update block above has executed.
        XCTAssertTrue(store.getAll().isEmpty, "Store should remain empty after trying to update a cleared request")

        // 5. Add a new request to ensure store functions correctly after clear
        let request3 = PhantomRequest(id: UUID(), url: url1, method: "PUT", headers: [:], body: nil)
        store.add(request3)

        let requestsAfterAdd = store.getAll()
        XCTAssertEqual(requestsAfterAdd.count, 1, "Store should function normally and contain 1 request after clear and add")
        XCTAssertEqual(requestsAfterAdd.first?.id, request3.id, "The newly added request should be the only one present")
    }
}
