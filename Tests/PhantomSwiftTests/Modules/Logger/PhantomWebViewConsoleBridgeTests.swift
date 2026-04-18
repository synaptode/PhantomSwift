#if DEBUG
import XCTest
@testable import PhantomSwift

#if canImport(WebKit)
import WebKit

final class PhantomWebViewConsoleBridgeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LogStore.shared.clear()
    }

    override func tearDown() {
        LogStore.shared.clear()
        super.tearDown()
    }

    func testCaptureAddsFormattedLogEntry() {
        PhantomWebViewConsoleBridge.capture(
            level: .error,
            message: "Bridge failed",
            tag: "HTMLBridge",
            sourceURL: "https://example.com/checkout",
            pageTitle: "Checkout"
        )

        let logs = LogStore.shared.getAll()
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.level, .error)
        XCTAssertEqual(logs.first?.tag, "HTMLBridge")
        XCTAssertEqual(
            logs.first?.message,
            "Bridge failed [Checkout • https://example.com/checkout]"
        )
    }

    func testBootstrapScriptContainsHandlerAndManualEmitter() {
        let script = PhantomWebViewConsoleBridge.bootstrapScript(handlerName: "customConsole")

        XCTAssertTrue(script.contains("customConsole"))
        XCTAssertTrue(script.contains("window.PhantomSwiftConsoleBridge"))
        XCTAssertTrue(script.contains("console[level] = function()"))
    }

    func testInstallRegistersHandlerOnConfiguration() {
        let configuration = WKWebViewConfiguration()
        let bridge = PhantomWebViewConsoleBridge()

        bridge.install(into: configuration)
        bridge.install(into: configuration)

        let scriptCount = configuration.userContentController.userScripts.count
        XCTAssertEqual(scriptCount, 1, "Installing the same bridge twice should not duplicate scripts.")
    }
}
#endif
#endif
