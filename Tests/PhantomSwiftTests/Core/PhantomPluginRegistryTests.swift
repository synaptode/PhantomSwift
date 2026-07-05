import XCTest
@testable import PhantomSwift

private struct MockDashboardPlugin: PhantomPlugin {
    let identifier: String
    let title: String
    let icon: String
    let rootViewController: UIViewController = UIViewController()
}

final class PhantomPluginRegistryTests: XCTestCase {
    func testMergedReplacesExistingPluginWithSameIdentifier() {
        let original = MockDashboardPlugin(identifier: "same-id", title: "Original", icon: "circle")
        let replacement = MockDashboardPlugin(identifier: "same-id", title: "Replacement", icon: "square")
        let other = MockDashboardPlugin(identifier: "other-id", title: "Other", icon: "triangle")

        let merged = PhantomPluginRegistry.merged(existing: [original, other], inserting: replacement)

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.map(\.identifier), ["other-id", "same-id"])
        XCTAssertEqual(merged.last?.title, "Replacement")
    }
}
