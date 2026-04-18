#if DEBUG
import Foundation

#if canImport(WebKit)
import WebKit

/// Bridges `console.*` output from a `WKWebView` into PhantomSwift's Console Logger.
///
/// The bridge is opt-in and should be installed on the `WKUserContentController`
/// that backs the web view configuration you own. This keeps ownership boundaries
/// explicit and avoids invasive swizzling of host app web views.
public final class PhantomWebViewConsoleBridge: NSObject {
    public enum ConsoleLevel: String, CaseIterable {
        case log
        case debug
        case info
        case warn
        case error

        fileprivate var logLevel: LogLevel {
            switch self {
            case .log: return .info
            case .debug: return .debug
            case .info: return .info
            case .warn: return .warning
            case .error: return .error
            }
        }
    }

    public struct Configuration {
        public var handlerName: String
        public var tag: String
        public var injectConsoleOverrides: Bool
        public var capturePageMetadata: Bool

        public init(
            handlerName: String = "phantomConsole",
            tag: String = "WebViewJS",
            injectConsoleOverrides: Bool = true,
            capturePageMetadata: Bool = true
        ) {
            self.handlerName = handlerName
            self.tag = tag
            self.injectConsoleOverrides = injectConsoleOverrides
            self.capturePageMetadata = capturePageMetadata
        }
    }

    private let configuration: Configuration
    private let proxy: ScriptMessageProxy
    private var installedControllers = Set<ObjectIdentifier>()

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.proxy = ScriptMessageProxy()
        super.init()
        self.proxy.owner = self
    }

    /// Installs the bridge into a `WKWebViewConfiguration`.
    public func install(into configuration: WKWebViewConfiguration) {
        install(into: configuration.userContentController)
    }

    /// Installs the bridge into a `WKUserContentController`.
    ///
    /// Call this before the target page is loaded so the console hook is present
    /// from the first script execution.
    public func install(into userContentController: WKUserContentController) {
        let identifier = ObjectIdentifier(userContentController)
        guard !installedControllers.contains(identifier) else { return }

        userContentController.add(proxy, name: configuration.handlerName)
        if configuration.injectConsoleOverrides {
            let script = WKUserScript(
                source: Self.bootstrapScript(
                    handlerName: configuration.handlerName,
                    includePageMetadata: configuration.capturePageMetadata
                ),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            userContentController.addUserScript(script)
        }
        installedControllers.insert(identifier)
    }

    /// Removes the native message handler from a controller.
    ///
    /// Note: previously injected user scripts remain attached to the controller,
    /// so this should be used when the configuration object itself is being torn down.
    public func detach(from userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: configuration.handlerName)
        installedControllers.remove(ObjectIdentifier(userContentController))
    }

    /// Best-effort bootstrap that forwards `console.*` calls from JavaScript into
    /// `window.webkit.messageHandlers[handlerName]`.
    public static func bootstrapScript(handlerName: String = "phantomConsole", includePageMetadata: Bool = true) -> String {
        let metadata = includePageMetadata
            ? """
                sourceURL: String(window.location && window.location.href || ''),
                pageTitle: String(document && document.title || '')
            """
            : """
                sourceURL: '',
                pageTitle: ''
            """

        return """
        (function() {
          if (window.__PHANTOM_SWIFT_CONSOLE_INSTALLED__) { return; }
          window.__PHANTOM_SWIFT_CONSOLE_INSTALLED__ = true;

          var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers['\(handlerName)'];
          if (!handler || !handler.postMessage) { return; }

          function serialize(value) {
            if (value === undefined) { return 'undefined'; }
            if (value === null) { return 'null'; }
            if (typeof value === 'string') { return value; }
            if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') {
              return String(value);
            }
            if (value instanceof Error) {
              return value.stack || value.message || String(value);
            }
            try {
              return JSON.stringify(value);
            } catch (error) {
              return String(value);
            }
          }

          function emit(level, args) {
            try {
              handler.postMessage({
                level: level,
                values: Array.prototype.slice.call(args).map(serialize),
                \(metadata)
              });
            } catch (error) {}
          }

          ['log', 'debug', 'info', 'warn', 'error'].forEach(function(level) {
            var original = console[level];
            console[level] = function() {
              emit(level, arguments);
              if (typeof original === 'function') {
                return original.apply(console, arguments);
              }
            };
          });

          window.PhantomSwiftConsoleBridge = {
            emit: function(level) {
              var args = Array.prototype.slice.call(arguments, 1);
              emit(level, args);
            }
          };
        })();
        """
    }

    /// Allows custom native JS bridges to forward a message directly into PhantomSwift.
    public static func capture(
        level: ConsoleLevel,
        message: String,
        tag: String = "WebViewJS",
        sourceURL: String? = nil,
        pageTitle: String? = nil
    ) {
        let formatted = formatMessage(message: message, sourceURL: sourceURL, pageTitle: pageTitle)
        log(level: level.logLevel, message: formatted, tag: tag)
    }

    fileprivate func handle(_ message: WKScriptMessage) {
        guard message.name == configuration.handlerName else { return }
        guard let payload = Payload(message.body) else { return }

        let formatted = Self.formatMessage(
            message: payload.joinedMessage,
            sourceURL: payload.sourceURL,
            pageTitle: payload.pageTitle
        )
        Self.log(level: payload.level.logLevel, message: formatted, tag: configuration.tag)
    }

    private static func formatMessage(message: String, sourceURL: String?, pageTitle: String?) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedTitle = pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var suffixes: [String] = []
        if !trimmedTitle.isEmpty {
            suffixes.append(trimmedTitle)
        }
        if !trimmedSource.isEmpty {
            suffixes.append(trimmedSource)
        }

        guard !suffixes.isEmpty else { return trimmedMessage }
        return "\(trimmedMessage) [\(suffixes.joined(separator: " • "))]"
    }

    private static func log(level: LogLevel, message: String, tag: String) {
        let entry = LogEntry(
            level: level,
            message: message,
            tag: tag,
            file: "PhantomWebViewConsoleBridge.swift",
            function: "console",
            line: 0
        )
        LogStore.shared.add(entry)
        print("\(entry.formatted) (PhantomWebViewConsoleBridge.swift:0)")
    }
}

private final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: PhantomWebViewConsoleBridge?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handle(message)
    }
}

private struct Payload {
    let level: PhantomWebViewConsoleBridge.ConsoleLevel
    let values: [String]
    let sourceURL: String?
    let pageTitle: String?

    init?(_ body: Any) {
        guard let dictionary = body as? [String: Any] else { return nil }
        guard let rawLevel = dictionary["level"] as? String,
              let level = PhantomWebViewConsoleBridge.ConsoleLevel(rawValue: rawLevel) else {
            return nil
        }

        self.level = level
        self.values = (dictionary["values"] as? [String]) ?? []
        self.sourceURL = dictionary["sourceURL"] as? String
        self.pageTitle = dictionary["pageTitle"] as? String
    }

    var joinedMessage: String {
        values.joined(separator: " ")
    }
}
#endif
#endif
