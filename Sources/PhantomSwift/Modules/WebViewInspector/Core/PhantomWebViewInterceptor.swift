#if DEBUG
import Foundation
#if canImport(WebKit)
import WebKit
import ObjectiveC

/// Automatically tracks WKWebView instances and intercepts JavaScript console logs and native bridge messages.
public final class PhantomWebViewInterceptor: NSObject {
    public static let shared = PhantomWebViewInterceptor()

    private let handlerName = "__phantomWebViewInspector"
    private var isStarted = false
    private let proxy = ScriptMessageProxy()
    private var installedControllers = Set<ObjectIdentifier>()

    private override init() {
        super.init()
        proxy.owner = self
    }

    /// Starts global automatic swizzling and tracking for all WKWebViews.
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        WKWebView.phantom_enableInspectorAutoTracking()
    }

    /// Injects the inspector script and message handler into a target controller.
    public func install(into userContentController: WKUserContentController) {
        let identifier = ObjectIdentifier(userContentController)
        guard !installedControllers.contains(identifier) else { return }
        installedControllers.insert(identifier)

        userContentController.add(proxy, name: handlerName)

        let script = WKUserScript(
            source: Self.bootstrapScript(handlerName: handlerName),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(script)
    }

    fileprivate func handle(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let kind = dict["kind"] as? String else {
            return
        }

        let payload = (dict["payload"] as? String) ?? ""
        let url = dict["url"] as? String
        let title = dict["title"] as? String

        if kind == "console" {
            let level = (dict["level"] as? String) ?? "log"
            PhantomWebViewStore.shared.add(
                kind: .console(level: level),
                payload: payload,
                sourceURL: url,
                pageTitle: title
            )
        } else if kind == "bridge" {
            let handler = (dict["handler"] as? String) ?? "postMessage"
            PhantomWebViewStore.shared.add(
                kind: .bridge(handler: handler),
                payload: payload,
                sourceURL: url,
                pageTitle: title
            )
        }
    }

    /// JavaScript injection payload for intercepting console and window.webkit.messageHandlers.
    public static func bootstrapScript(handlerName: String) -> String {
        return """
        (function() {
          if (window.__PHANTOM_WEBVIEW_INSPECTOR_INSTALLED__) { return; }
          window.__PHANTOM_WEBVIEW_INSPECTOR_INSTALLED__ = true;

          var targetHandler = '\(handlerName)';

          function postToNative(data) {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[targetHandler]) {
                window.webkit.messageHandlers[targetHandler].postMessage(data);
              }
            } catch (err) {}
          }

          function serialize(val) {
            if (val === undefined) return 'undefined';
            if (val === null) return 'null';
            if (typeof val === 'string') return val;
            if (typeof val === 'number' || typeof val === 'boolean' || typeof val === 'bigint') return String(val);
            if (val instanceof Error) return val.stack || val.message || String(val);
            try {
              return JSON.stringify(val);
            } catch (err) {
              return String(val);
            }
          }

          var levels = ['log', 'info', 'warn', 'error', 'debug'];
          levels.forEach(function(lvl) {
            var original = console[lvl];
            console[lvl] = function() {
              var args = Array.prototype.slice.call(arguments);
              postToNative({
                kind: 'console',
                level: lvl,
                payload: args.map(serialize).join(' '),
                url: String((window.location && window.location.href) || ''),
                title: String(document.title || '')
              });
              if (typeof original === 'function') {
                original.apply(console, arguments);
              }
            };
          });

          function wrapMessageHandlers() {
            if (!window.webkit || !window.webkit.messageHandlers) return;
            if (window.webkit.messageHandlers.__phantom_proxied__) return;

            var originalHandlers = window.webkit.messageHandlers;
            try {
              window.webkit.messageHandlers = new Proxy(originalHandlers, {
                get: function(target, prop, receiver) {
                  if (prop === '__phantom_proxied__') return true;
                  var handler = target[prop];
                  if (!handler || prop === targetHandler || prop === '__phantomConsole') {
                    return handler;
                  }
                  return {
                    postMessage: function(body) {
                      postToNative({
                        kind: 'bridge',
                        handler: String(prop),
                        payload: serialize(body),
                        url: String((window.location && window.location.href) || ''),
                        title: String(document.title || '')
                      });
                      return handler.postMessage(body);
                    }
                  };
                }
              });
            } catch (err) {}
          }

          wrapMessageHandlers();
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', wrapMessageHandlers);
          }
        })();
        """
    }
}

private final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: PhantomWebViewInterceptor?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handle(message: message)
    }
}

private var phantomWebViewInspectorAssociatedKey: UInt8 = 0

private extension WKWebView {
    static func phantom_enableInspectorAutoTracking() {
        PhantomSwizzler.swizzle(
            cls: WKWebView.self,
            originalSelector: #selector(WKWebView.didMoveToWindow),
            swizzledSelector: #selector(WKWebView.phantom_inspector_didMoveToWindow)
        )
    }

    @objc func phantom_inspector_didMoveToWindow() {
        self.phantom_inspector_didMoveToWindow()

        guard window != nil else { return }
        PhantomWebViewStore.shared.register(webView: self)

        guard !phantom_hasInspectorInstalled else { return }
        PhantomWebViewInterceptor.shared.install(into: configuration.userContentController)
        phantom_markInspectorInstalled()
    }

    var phantom_hasInspectorInstalled: Bool {
        (objc_getAssociatedObject(self, &phantomWebViewInspectorAssociatedKey) as? NSNumber)?.boolValue ?? false
    }

    func phantom_markInspectorInstalled() {
        objc_setAssociatedObject(
            self,
            &phantomWebViewInspectorAssociatedKey,
            NSNumber(value: true),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
#endif
#endif
