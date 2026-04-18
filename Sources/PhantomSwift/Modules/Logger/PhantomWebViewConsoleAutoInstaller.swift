#if DEBUG
import Foundation

#if canImport(WebKit)
import WebKit

/// Automatically installs PhantomSwift's console bridge into new `WKWebView`
/// instances created after launch, so hybrid HTML/native stacks work out of the box.
internal final class PhantomWebViewConsoleAutoInstaller {
    static let shared = PhantomWebViewConsoleAutoInstaller()

    private let bridge = PhantomWebViewConsoleBridge(
        configuration: .init(handlerName: "__phantomConsole", tag: "WebViewJS")
    )
    private var isStarted = false

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true
        WKWebView.phantom_enableConsoleAutoInstall()
    }

    fileprivate func installIfNeeded(on webView: WKWebView) {
        bridge.install(into: webView.configuration)
    }
}

private var phantomConsoleBridgeAssociatedKey: UInt8 = 0

private extension WKWebView {
    static func phantom_enableConsoleAutoInstall() {
        PhantomSwizzler.swizzle(
            cls: WKWebView.self,
            originalSelector: #selector(WKWebView.didMoveToWindow),
            swizzledSelector: #selector(WKWebView.phantom_didMoveToWindow)
        )
    }

    @objc func phantom_didMoveToWindow() {
        self.phantom_didMoveToWindow()

        guard window != nil else { return }
        guard !phantom_hasConsoleBridgeInstalled else { return }

        PhantomWebViewConsoleAutoInstaller.shared.installIfNeeded(on: self)
        phantom_markConsoleBridgeInstalled()
    }

    var phantom_hasConsoleBridgeInstalled: Bool {
        (objc_getAssociatedObject(self, &phantomConsoleBridgeAssociatedKey) as? NSNumber)?.boolValue ?? false
    }

    func phantom_markConsoleBridgeInstalled() {
        objc_setAssociatedObject(
            self,
            &phantomConsoleBridgeAssociatedKey,
            NSNumber(value: true),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
#endif
#endif
