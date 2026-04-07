#if DEBUG
import XCTest
@testable import PhantomSwift

final class LogStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear shared store before each test to ensure a clean state
        LogStore.shared.clear()
    }

    override func tearDown() {
        LogStore.shared.clear()
        super.tearDown()
    }

    private func createDummyLog(message: String) -> LogEntry {
        return LogEntry(
            level: .info,
            message: message,
            tag: nil,
            file: "Test.swift",
            function: "test",
            line: 1
        )
    }

    func testAddSingleEntry() {
        let store = LogStore.shared
        let log = createDummyLog(message: "Test message 1")

        store.add(log)

        let logs = store.getAll()
        XCTAssertEqual(logs.count, 1, "Store should contain exactly 1 log.")
        XCTAssertEqual(logs.first?.message, "Test message 1", "Stored log message should match.")
    }

    func testBufferOverflow() {
        let store = LogStore.shared
        // The default maxCount is 1000. Let's add 1005 logs to test overflow.
        let overflowCount = 1005
        let maxCount = 1000

        for i in 0..<overflowCount {
            store.add(createDummyLog(message: "Message \(i)"))
        }

        let logs = store.getAll()

        XCTAssertEqual(logs.count, maxCount, "Store should not exceed maxCount.")
        // The oldest 5 logs (Message 0 to 4) should be overwritten.
        // The first log in the buffer should now be Message 5.
        XCTAssertEqual(logs.first?.message, "Message 5", "Oldest entries should be overwritten when buffer overflows.")
        XCTAssertEqual(logs.last?.message, "Message 1004", "Newest entry should be at the end.")
    }

    func testConcurrentAdds() {
        let store = LogStore.shared
        let expectation = self.expectation(description: "Concurrent adds")
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.phantomswift.test.concurrent", attributes: .concurrent)

        let addCount = 100

        for i in 0..<addCount {
            dispatchGroup.enter()
            concurrentQueue.async {
                store.add(self.createDummyLog(message: "Concurrent \(i)"))
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0, handler: nil)

        let logs = store.getAll()
        XCTAssertEqual(logs.count, addCount, "Store should safely add all concurrent entries.")
    }
}
#endif
