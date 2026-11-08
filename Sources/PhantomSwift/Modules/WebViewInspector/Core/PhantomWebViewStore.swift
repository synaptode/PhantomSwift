#if DEBUG
import Foundation
#if canImport(WebKit)
import WebKit
#endif

/// Log classification for WKWebView events.
public enum PhantomWebViewLogKind: Hashable {
    case console(level: String)
    case bridge(handler: String)

    public var title: String {
        switch self {
        case .console(let level): return "console.\(level)"
        case .bridge(let handler): return "postMessage: \(handler)"
        }
    }

    public var isError: Bool {
        switch self {
        case .console(let level): return level.lowercased() == "error"
        case .bridge: return false
        }
    }
}

/// A captured WKWebView event containing JavaScript console output or JS-to-Native bridge messages.
public struct PhantomWebViewLogEntry: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let kind: PhantomWebViewLogKind
    public let payload: String
    public let sourceURL: String?
    public let pageTitle: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: PhantomWebViewLogKind,
        payload: String,
        sourceURL: String? = nil,
        pageTitle: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.payload = payload
        self.sourceURL = sourceURL
        self.pageTitle = pageTitle
    }
}

#if canImport(WebKit)
private final class WeakWebViewBox {
    weak var value: WKWebView?
    let identifier: ObjectIdentifier

    init(_ value: WKWebView) {
        self.value = value
        self.identifier = ObjectIdentifier(value)
    }
}
#endif

/// Thread-safe central store for tracked WKWebViews and captured web runtime logs.
public final class PhantomWebViewStore {
    public static let shared = PhantomWebViewStore()

    public static let didUpdateNotification = "webViewUpdated"

    private let queue = DispatchQueue(label: "com.phantomswift.webviewstore", attributes: .concurrent)
    private var entries: [PhantomWebViewLogEntry] = []
    private let maxEntries = 500

    #if canImport(WebKit)
    private var webViewBoxes: [WeakWebViewBox] = []
    #endif

    private init() {}

    /// Appends a new web view log entry and notifies listeners.
    public func add(
        kind: PhantomWebViewLogKind,
        payload: String,
        sourceURL: String? = nil,
        pageTitle: String? = nil
    ) {
        let entry = PhantomWebViewLogEntry(
            kind: kind,
            payload: payload,
            sourceURL: sourceURL,
            pageTitle: pageTitle
        )
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            DispatchQueue.main.async {
                PhantomEventBus.shared.post(.webViewUpdated)
            }
        }
    }

    /// Returns a snapshot of all recorded logs.
    public var allLogs: [PhantomWebViewLogEntry] {
        queue.sync { entries }
    }

    /// Number of recorded logs.
    public var count: Int {
        queue.sync { entries.count }
    }

    /// Clears all stored web runtime logs.
    public func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.entries.removeAll()
            DispatchQueue.main.async {
                PhantomEventBus.shared.post(.webViewUpdated)
            }
        }
    }

    #if canImport(WebKit)
    /// Registers an alive WKWebView instance to be tracked.
    public func register(webView: WKWebView) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.webViewBoxes.removeAll(where: { $0.value == nil })
            let id = ObjectIdentifier(webView)
            if !self.webViewBoxes.contains(where: { $0.identifier == id }) {
                self.webViewBoxes.append(WeakWebViewBox(webView))
            }
            DispatchQueue.main.async {
                PhantomEventBus.shared.post(.webViewUpdated)
            }
        }
    }

    /// Returns all currently living WKWebViews.
    public func activeWebViews() -> [WKWebView] {
        queue.sync {
            webViewBoxes.compactMap { $0.value }
        }
    }
    #endif
}
#endif
