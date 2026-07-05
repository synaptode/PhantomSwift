import XCTest
@testable import PhantomSwift

final class PhantomDashboardSearchTests: XCTestCase {
    func testScoreMatchesSubtitleKeywords() {
        let score = PhantomDashboardSearch.score(
            query: "retain cycle",
            title: "Leak Tracker",
            subtitle: "Retain-cycle and leak tracking"
        )

        XCTAssertEqual(score, 3)
    }

    func testScorePrefersTitlePrefixOverSubtitleMatch() {
        let titleScore = PhantomDashboardSearch.score(
            query: "net",
            title: "Network",
            subtitle: "Live HTTP/HTTPS inspection"
        )

        let subtitleScore = PhantomDashboardSearch.score(
            query: "http",
            title: "Network",
            subtitle: "Live HTTP/HTTPS inspection"
        )

        XCTAssertEqual(titleScore, 1)
        XCTAssertEqual(subtitleScore, 3)
    }

    func testScoreRejectsUnrelatedQueries() {
        let score = PhantomDashboardSearch.score(
            query: "printer",
            title: "Logger",
            subtitle: "Central log console and bridges"
        )

        XCTAssertNil(score)
    }
}
