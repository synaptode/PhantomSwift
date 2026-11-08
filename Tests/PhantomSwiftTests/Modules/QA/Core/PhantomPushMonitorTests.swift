import XCTest
@testable import PhantomSwift

final class PhantomPushMonitorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhantomPushStore.shared.clear()
    }

    override func tearDown() {
        PhantomPushStore.shared.clear()
        super.tearDown()
    }

    func testPushRecordModel() {
        let record = PhantomPushRecord(
            identifier: "test-notif-1",
            title: "Welcome",
            body: "Hello world",
            badge: 3,
            sound: "default",
            categoryIdentifier: "GENERAL",
            userInfoJSON: "{\"custom_key\": \"custom_val\"}",
            source: .local
        )

        XCTAssertEqual(record.identifier, "test-notif-1")
        XCTAssertEqual(record.title, "Welcome")
        XCTAssertEqual(record.body, "Hello world")
        XCTAssertEqual(record.badge, 3)
        XCTAssertEqual(record.sound, "default")
        XCTAssertEqual(record.source, .local)
        XCTAssertEqual(record.categoryIdentifier, "GENERAL")
        XCTAssertFalse(record.userInfoJSON.isEmpty)
    }

    func testPushStoreAddAndClear() {
        let store = PhantomPushStore.shared
        XCTAssertEqual(store.count, 0)

        let record1 = PhantomPushRecord(
            identifier: "alert-1",
            title: "Alert 1",
            body: "Body 1",
            source: .remote
        )
        let record2 = PhantomPushRecord(
            identifier: "alert-2",
            title: "Alert 2",
            body: "Body 2",
            source: .local
        )

        store.add(record1)
        store.add(record2)

        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store.getAll().count, 2)
        XCTAssertEqual(store.getAll().first?.title, "Alert 2")

        store.clear()
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(store.getAll().isEmpty)
    }

    func testPushStoreMaxLimit() {
        let store = PhantomPushStore.shared
        for index in 0..<505 {
            let record = PhantomPushRecord(
                identifier: "alert-\(index)",
                title: "Alert \(index)",
                body: "Body \(index)",
                source: .simulated
            )
            store.add(record)
        }

        XCTAssertEqual(store.count, 500)
    }

    func testAPNsTokenRegistration() {
        let store = PhantomPushStore.shared
        store.setDeviceToken("deadbeef12345678")
        XCTAssertEqual(store.apnsToken, "deadbeef12345678")
    }

    func testEventBusIntegration() {
        let exp = expectation(description: "Event bus receives push captured")
        let store = PhantomPushStore.shared

        final class PushTestObserver: PhantomEventObserver {
            var onReceived: ((PhantomPushRecord) -> Void)?
            func onEvent(_ event: PhantomEvent) {
                if case .pushNotificationCaptured(let rec) = event {
                    onReceived?(rec)
                }
            }
        }

        let observer = PushTestObserver()
        observer.onReceived = { rec in
            if rec.title == "EventBusTest" {
                exp.fulfill()
            }
        }
        PhantomEventBus.shared.subscribe(observer, to: "pushNotificationCaptured")

        let record = PhantomPushRecord(
            identifier: "event-bus-test",
            title: "EventBusTest",
            body: "Testing EventBus",
            source: .remote
        )
        store.add(record)

        wait(for: [exp], timeout: 2.0)
        PhantomEventBus.shared.unsubscribe(observer, from: "pushNotificationCaptured")
    }
}
