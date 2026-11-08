import XCTest
#if canImport(WebKit)
import WebKit
#endif
@testable import PhantomSwift

final class PhantomWebViewStorageManagerTests: XCTestCase {

    #if canImport(WebKit)
    func testManagerFetchCookies() {
        let exp = expectation(description: "Fetch cookies completes")
        PhantomWebViewStorageManager.shared.fetchCookies { cookies in
            XCTAssertNotNil(cookies)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testManagerFetchWebsiteData() {
        let exp = expectation(description: "Fetch website data completes")
        PhantomWebViewStorageManager.shared.fetchWebsiteDataRecords { records in
            XCTAssertNotNil(records)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
    #endif
}
