import XCTest
@testable import PhantomSwift

final class PhantomWebViewStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PhantomWebViewStore.shared.clear()
    }

    override func tearDown() {
        PhantomWebViewStore.shared.clear()
        super.tearDown()
    }

    func testAddConsoleLog() {
        let exp = expectation(description: "Store adds console log")

        PhantomWebViewStore.shared.add(
            kind: .console(level: "warn"),
            payload: "Deprecation warning in bundle.js",
            sourceURL: "https://example.com/app.js",
            pageTitle: "Example App"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let logs = PhantomWebViewStore.shared.allLogs
            XCTAssertEqual(logs.count, 1)
            let first = logs.first
            XCTAssertEqual(first?.payload, "Deprecation warning in bundle.js")
            XCTAssertEqual(first?.sourceURL, "https://example.com/app.js")
            XCTAssertEqual(first?.pageTitle, "Example App")
            XCTAssertEqual(first?.kind.title, "console.warn")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testAddBridgeMessage() {
        let exp = expectation(description: "Store adds bridge message")

        PhantomWebViewStore.shared.add(
            kind: .bridge(handler: "onPaymentSuccess"),
            payload: "{\"orderId\": \"12345\"}",
            sourceURL: "https://example.com/checkout",
            pageTitle: "Checkout"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let logs = PhantomWebViewStore.shared.allLogs
            XCTAssertEqual(logs.count, 1)
            let first = logs.first
            XCTAssertEqual(first?.kind.title, "postMessage: onPaymentSuccess")
            XCTAssertEqual(first?.payload, "{\"orderId\": \"12345\"}")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testClearLogs() {
        let exp = expectation(description: "Store clears logs")

        PhantomWebViewStore.shared.add(
            kind: .console(level: "log"),
            payload: "Initial log"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertEqual(PhantomWebViewStore.shared.allLogs.count, 1)
            PhantomWebViewStore.shared.clear()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                XCTAssertEqual(PhantomWebViewStore.shared.allLogs.count, 0)
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 1.0)
    }

    #if canImport(WebKit)
    func testBootstrapScriptContainsConsoleAndProxyHooks() {
        let script = PhantomWebViewInterceptor.bootstrapScript(handlerName: "testHandler")
        XCTAssertTrue(script.contains("testHandler"))
        XCTAssertTrue(script.contains("window.webkit.messageHandlers"))
        XCTAssertTrue(script.contains("__phantom_proxied__"))
        XCTAssertTrue(script.contains("postMessage"))
        XCTAssertTrue(script.contains("console[lvl]"))
    }
    #endif

    func testWebViewFeatureDescriptor() {
        let descriptor = PhantomFeatureCatalog.descriptor(for: .webViewInspector)
        XCTAssertEqual(descriptor.title, "WebView")
        XCTAssertEqual(descriptor.icon, "globe")
        XCTAssertFalse(descriptor.subtitle.isEmpty)
        let vc = descriptor.makeViewController(PhantomFeaturePresentationContext(inspectedRootView: UIView()))
        XCTAssertTrue(vc is WebViewInspectorVC)
    }
}
