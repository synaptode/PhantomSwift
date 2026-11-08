#if canImport(UIKit)
import XCTest
import UIKit
@testable import PhantomSwift

final class PhantomDashboardToggleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhantomDashboardVC.current = nil
    }

    override func tearDown() {
        PhantomDashboardVC.current = nil
        super.tearDown()
    }

    func testActiveDashboardDetectsCurrentInstance() {
        XCTAssertNil(PhantomPresentationResolver.activeDashboard())
        XCTAssertFalse(PhantomSwift.shared.isDashboardVisible)

        let dashboard = PhantomDashboardVC()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = dashboard
        window.makeKeyAndVisible()

        PhantomDashboardVC.current = dashboard
        XCTAssertNotNil(PhantomPresentationResolver.activeDashboard())
        XCTAssertTrue(PhantomSwift.shared.isDashboardVisible)
    }

    func testIsPhantomViewControllerIdentification() {
        let dashboard = PhantomDashboardVC()
        XCTAssertTrue(PhantomPresentationResolver.isPhantomViewController(dashboard))

        _ = UINavigationController(rootViewController: UIViewController())
        let dummyParent = UIViewController()
        dummyParent.present(dashboard, animated: false)

        XCTAssertTrue(PhantomPresentationResolver.isPhantomViewController(dashboard))

        let regularVC = UIViewController()
        XCTAssertFalse(PhantomPresentationResolver.isPhantomViewController(regularVC))
    }

    func testShowDashboardWhenAlreadyVisibleDoesNotDuplicate() {
        let dashboard = PhantomDashboardVC()
        PhantomDashboardVC.current = dashboard
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = dashboard
        window.makeKeyAndVisible()

        XCTAssertTrue(PhantomSwift.shared.isDashboardVisible)

        // Calling showDashboard should be ignored
        PhantomSwift.shared.showDashboard()
        XCTAssertTrue(PhantomSwift.shared.isDashboardVisible)
    }
}
#endif
