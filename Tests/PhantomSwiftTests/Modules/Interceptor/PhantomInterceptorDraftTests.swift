#if DEBUG
import XCTest
@testable import PhantomSwift
import PhantomSwiftNetworking

final class PhantomInterceptorDraftTests: XCTestCase {

    func testRecommendedPatternUsesHostAndPath() {
        let request = PhantomRequest(
            url: URL(string: "https://api.example.com/v1/users?page=1")!,
            method: "GET",
            headers: [:],
            body: nil
        )

        let pattern = PhantomInterceptorDraft.recommendedPattern(for: request)

        XCTAssertEqual(pattern, "*api.example.com/v1/users*")
    }

    func testMockDraftUsesResponseMetadataAndBody() {
        let body = #"{"ok":true}"#.data(using: .utf8)
        let request = PhantomRequest(
            url: URL(string: "https://api.example.com/v1/users")!,
            method: "POST",
            headers: ["Accept": "application/json"],
            body: nil
        )
        let response = PhantomResponse(
            statusCode: 201,
            headers: ["Content-Type": "application/json"],
            body: body,
            duration: 0.2
        )

        let draft = PhantomInterceptorDraft.mock(from: request, response: response)

        XCTAssertEqual(draft.kind, .mock)
        XCTAssertEqual(draft.method, "POST")
        XCTAssertEqual(draft.statusCode, 201)
        XCTAssertEqual(draft.headers["Content-Type"], "application/json")
        XCTAssertTrue(draft.bodyText?.contains("\"ok\"") == true)
    }

    func testRedirectDraftDefaultsToOriginalURL() {
        let request = PhantomRequest(
            url: URL(string: "https://api.example.com/v1/users")!,
            method: "GET",
            headers: [:],
            body: nil
        )

        let draft = PhantomInterceptorDraft.redirect(for: request)

        XCTAssertEqual(draft.kind, .redirect)
        XCTAssertEqual(draft.redirectDestination, request.url.absoluteString)
    }
}
#endif
