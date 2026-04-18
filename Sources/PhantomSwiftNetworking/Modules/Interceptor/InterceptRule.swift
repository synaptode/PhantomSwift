#if DEBUG
import Foundation

/// A high-level structure that wraps an InterceptRule with state and metadata.
public struct PhantomInterceptRule: Identifiable {
    public let id: UUID
    public var rule: InterceptRule
    public var isEnabled: Bool
    public let createdAt: Date
    /// Number of times this rule has matched and fired.
    public var hitCount: Int

    public init(rule: InterceptRule, isEnabled: Bool = true) {
        self.id = UUID()
        self.rule = rule
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.hitCount = 0
    }
}

/// Defines a rule for intercepting a network request.
public enum InterceptRule {
    /// Redirect request URL to a different server.
    case redirect(from: String, to: String)
    
    /// Inject a fake HTTP response without hitting the network.
    case mockResponse(urlPattern: String, method: String?, statusCode: Int, headers: [String: String], body: Data?)
    
    /// Add artificial delay before the request is processed.
    case delay(urlPattern: String, seconds: TimeInterval)
    
    /// Drop the request entirely and return an error.
    case block(urlPattern: String)
    
    /// Modify request headers or body before sending.
    case modifyRequest(urlPattern: String, transform: (inout URLRequest) -> Void)
    
    /// Serve response from a local file in the app sandbox.
    case mapLocal(urlPattern: String, fileName: String)
    
    /// Returns the URL pattern this rule applies to.
    public var urlPattern: String {
        switch self {
        case .redirect(let from, _): return from
        case .mockResponse(let pattern, _, _, _, _): return pattern
        case .delay(let pattern, _): return pattern
        case .block(let pattern): return pattern
        case .modifyRequest(let pattern, _): return pattern
        case .mapLocal(let pattern, _): return pattern
        }
    }
    
    /// Returns the HTTP method this rule applies to (if any).
    public var method: String? {
        switch self {
        case .mockResponse(_, let method, _, _, _): return method
        default: return nil
        }
    }
    
    /// User-facing description for the rule type.
    public var typeDisplayName: String {
        switch self {
        case .redirect: return "Redirect"
        case .mockResponse: return "Mock Response"
        case .delay: return "Network Delay"
        case .block: return "Block Request"
        case .modifyRequest: return "Modify Request"
        case .mapLocal: return "Map Local"
        }
    }

    /// Compact detail shown in management UIs.
    public var detailDisplayName: String {
        switch self {
        case .redirect(_, let to):
            return "To \(to)"
        case .mockResponse(_, let method, let statusCode, let headers, let body):
            let methodText = method ?? "ANY"
            return "\(methodText) • HTTP \(statusCode) • \(headers.count) headers • \(body?.count ?? 0) B"
        case .delay(_, let seconds):
            return String(format: "%.1fs latency injection", seconds)
        case .block:
            return "Hard fail before transport"
        case .modifyRequest(_, _):
            return "Applies request transform"
        case .mapLocal(_, let fileName):
            return "Serves \(fileName)"
        }
    }

    public var methodDisplayName: String? {
        switch self {
        case .mockResponse(_, let method, _, _, _):
            return method ?? "ANY"
        default:
            return nil
        }
    }
}
#endif
