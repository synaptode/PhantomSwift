import XCTest
@testable import PhantomSwift

private struct ResetTestPlugin: PhantomPlugin {
    let identifier: String
    let title: String
    let icon: String
    let rootViewController: UIViewController = UIViewController()
}

private final class ResetTestEventObserver: PhantomEventObserver {
    var receivedEvents: [PhantomEvent] = []
    var onEventReceived: (() -> Void)?

    func onEvent(_ event: PhantomEvent) {
        receivedEvents.append(event)
        onEventReceived?()
    }
}

final class PhantomSwiftResetTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PhantomSwift.shared.resetForTesting()
    }

    override func tearDown() {
        PhantomSwift.shared.resetForTesting()
        super.tearDown()
    }

    func testResetForTestingClearsLaunchAndPluginState() {
        let sut = PhantomSwift.shared

        sut.register(plugin: ResetTestPlugin(identifier: "test-plugin", title: "Test", icon: "star"))

        XCTAssertEqual(sut.registeredPlugins.count, 1)
        XCTAssertFalse(sut.isLaunched)

        PhantomSwift.launch()
        XCTAssertTrue(sut.isLaunched)

        sut.resetForTesting()

        XCTAssertFalse(sut.isLaunched)
        XCTAssertTrue(sut.registeredPlugins.isEmpty)
    }

    func testLaunchIsIdempotentForAppLaunchedEvent() {
        let sut = PhantomSwift.shared
        let observer = ResetTestEventObserver()
        let expectation = self.expectation(description: "App launched event received once")

        observer.onEventReceived = {
            if observer.receivedEvents.count == 1 {
                expectation.fulfill()
            }
        }

        PhantomEventBus.shared.subscribe(observer, to: PhantomEvent.appLaunched.name)

        sut.config.environment = .custom([])
        sut.config.triggers = []

        PhantomSwift.launch()
        PhantomSwift.launch()

        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertEqual(observer.receivedEvents.count, 1)
            XCTAssertTrue(observer.receivedEvents.allSatisfy {
                if case .appLaunched = $0 { return true }
                return false
            })
        }

        PhantomEventBus.shared.unsubscribeAll(observer)
    }
}
