import XCTest
@testable import PhantomSwift

final class PhantomRequestStoreClearTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhantomRequestStore.shared.clear()
    }

    override func tearDown() {
        PhantomRequestStore.shared.clear()
        super.tearDown()
    }

    func testClearRequests() {
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

        let requestsBeforeClear = store.getAll()
        XCTAssertEqual(requestsBeforeClear.count, 2, "Store should contain 2 requests before clear")

        store.clear()

        let requestsAfterClear = store.getAll()
        XCTAssertTrue(requestsAfterClear.isEmpty, "Store should be empty after clear")

        var updatedRequest1 = request1
        updatedRequest1.status = .completed
        store.update(updatedRequest1)

        XCTAssertTrue(store.getAll().isEmpty, "Store should remain empty after trying to update a cleared request")

        let request3 = PhantomRequest(id: UUID(), url: url1, method: "PUT", headers: [:], body: nil)
        store.add(request3)

        let requestsAfterAdd = store.getAll()
        XCTAssertEqual(requestsAfterAdd.count, 1, "Store should function normally and contain 1 request after clear and add")
        XCTAssertEqual(requestsAfterAdd.first?.id, request3.id, "The newly added request should be the only one present")
    }
}
