import XCTest
import PhantomSwift

final class PhantomExampleTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testConfigureUpdatesSharedConfig() {
        let originalConfig = PhantomSwift.shared.config
        defer { PhantomSwift.shared.config = originalConfig }

        PhantomSwift.configure { config in
            config.environment = .dev
            config.theme = .dark
            config.triggers = [.shake, .dynamicIsland]
        }

        let updatedConfig = PhantomSwift.shared.config
        XCTAssertEqual(updatedConfig.environment, .dev)
        XCTAssertEqual(updatedConfig.theme, .dark)
        XCTAssertTrue(updatedConfig.triggers.contains(.shake))
        XCTAssertTrue(updatedConfig.triggers.contains(.dynamicIsland))
    }

    func testEventBusDeduplicatesAndUnsubscribesObservers() {
        let observer = EventProbe()
        let deliveredOnce = expectation(description: "event delivered exactly once")
        deliveredOnce.expectedFulfillmentCount = 1

        observer.onEventReceived = { event in
            guard case .log(let message) = event else { return }
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(message, "hello")
            deliveredOnce.fulfill()
        }

        PhantomEventBus.shared.subscribe(observer, to: "log")
        PhantomEventBus.shared.subscribe(observer, to: "log")
        PhantomEventBus.shared.post(.log("hello"))

        wait(for: [deliveredOnce], timeout: 2.0)

        let shouldNotDeliver = expectation(description: "observer removed")
        shouldNotDeliver.isInverted = true

        observer.onEventReceived = { _ in
            shouldNotDeliver.fulfill()
        }

        PhantomEventBus.shared.unsubscribe(observer, from: "log")
        PhantomEventBus.shared.post(.log("ignored"))

        wait(for: [shouldNotDeliver], timeout: 0.5)
    }
}

private final class EventProbe: PhantomEventObserver {
    var onEventReceived: ((PhantomEvent) -> Void)?

    func onEvent(_ event: PhantomEvent) {
        onEventReceived?(event)
    }
}
