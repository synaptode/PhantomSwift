import XCTest
@testable import PhantomSwift

final class NetworkListVCTests: XCTestCase {
    func testFilteredRequestsAppliesSearchAndStatusFilters() {
        let url1 = URL(string: "https://api.example.com/users")!
        let url2 = URL(string: "https://api.example.com/orders")!
        let url3 = URL(string: "https://api.example.com/pending")!

        var completed = PhantomRequest(id: UUID(), url: url1, method: "GET", headers: [:], body: nil)
        completed.response = PhantomResponse(statusCode: 200, headers: [:], body: nil, duration: 0.1)
        completed.status = .completed

        var serverError = PhantomRequest(id: UUID(), url: url2, method: "POST", headers: [:], body: nil)
        serverError.response = PhantomResponse(statusCode: 500, headers: [:], body: nil, duration: 0.2)
        serverError.status = .completed

        let pending = PhantomRequest(id: UUID(), url: url3, method: "PUT", headers: [:], body: nil)

        let requests = [completed, serverError, pending]

        let searchResults = NetworkListVC.filteredRequests(from: requests, searchText: "orders", activeFilter: "All")
        XCTAssertEqual(searchResults.map(\.id), [serverError.id])

        let statusResults = NetworkListVC.filteredRequests(from: requests, searchText: "", activeFilter: "5xx")
        XCTAssertEqual(statusResults.map(\.id), [serverError.id])

        let pendingResults = NetworkListVC.filteredRequests(from: requests, searchText: "", activeFilter: "Pending")
        XCTAssertEqual(pendingResults.map(\.id), [pending.id])
    }
}
