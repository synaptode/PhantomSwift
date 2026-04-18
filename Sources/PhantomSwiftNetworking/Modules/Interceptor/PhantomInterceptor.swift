#if DEBUG
import Foundation

// MARK: - MockoonConfig

/// Persistent configuration for redirecting all traffic to a local Mockoon server.
public struct MockoonConfig: Codable {
    public var host: String
    public var port: Int
    public var isEnabled: Bool
    /// URL patterns (supports * wildcard) that should bypass the Mockoon redirect.
    public var excludePatterns: [String]

    public static let defaultConfig = MockoonConfig(host: "localhost", port: 3000, isEnabled: false, excludePatterns: [])

    private static let defaultsKey = "com.phantomswift.mockoon.config"

    public static func load() -> MockoonConfig {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(MockoonConfig.self, from: data) else {
            return .defaultConfig
        }
        return config
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: MockoonConfig.defaultsKey)
    }
}

/// Singleton engine managing network interception rules.
public final class PhantomInterceptor {
    public static let shared = PhantomInterceptor()
    
    private let queue = DispatchQueue(label: "com.phantomswift.interceptor", attributes: .concurrent)
    private let maxRecentEvents = 20
    private var rules: [PhantomInterceptRule] = []
    private var recentEvents: [RecentEvent] = []
    private var _mockoonConfig: MockoonConfig = MockoonConfig.load()

    private init() {}

    // MARK: - Mockoon

    /// The current Mockoon redirect configuration.
    public var mockoonConfig: MockoonConfig {
        return queue.sync { _mockoonConfig }
    }

    /// Persists and applies a new Mockoon configuration.
    public func updateMockoon(_ config: MockoonConfig) {
        queue.sync(flags: .barrier) {
            self._mockoonConfig = config
            config.save()
        }
    }

    /// If Mockoon is enabled, returns a URL with its scheme/host/port rewritten to the
    /// Mockoon server while preserving the original path, query, and fragment.
    /// Returns nil if Mockoon is disabled or if the URL matches an exclude pattern.
    public func mockoonRedirect(for url: URL?) -> URL? {
        guard let url = url else { return nil }
        return queue.sync {
            guard _mockoonConfig.isEnabled else { return nil }
            // Check exclude patterns — if matched, bypass Mockoon
            let isExcluded = _mockoonConfig.excludePatterns.contains { pattern in
                PhantomRuleMatcher.matches(url: url, pattern: pattern)
            }
            guard !isExcluded else { return nil }
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.scheme = "http"
            comps?.host = _mockoonConfig.host
            comps?.port = _mockoonConfig.port
            return comps?.url
        }
    }
    
    /// Adds a new interception rule.
    public func add(rule: InterceptRule) {
        queue.sync(flags: .barrier) {
            let wrappedRule = PhantomInterceptRule(rule: rule)
            self.rules.append(wrappedRule)
        }
    }
    
    /// Toggles a rule's enabled state.
    public func toggle(id: UUID) {
        queue.sync(flags: .barrier) {
            if let index = self.rules.firstIndex(where: { $0.id == id }) {
                self.rules[index].isEnabled.toggle()
            }
        }
    }
    
    /// Deletes a rule.
    public func delete(id: UUID) {
        queue.sync(flags: .barrier) {
            self.rules.removeAll(where: { $0.id == id })
        }
    }
    
    /// Removes all rules.
    public func clear() {
        queue.sync(flags: .barrier) {
            self.rules.removeAll()
            self.recentEvents.removeAll()
        }
    }

    /// Resets hit counters on all rules to zero.
    public func resetHitCounts() {
        queue.sync(flags: .barrier) {
            for i in self.rules.indices { self.rules[i].hitCount = 0 }
        }
    }
    
    /// Finds the first matching rule for a given request and increments its hit counter.
    public func rule(for request: URLRequest) -> InterceptRule? {
        guard let url = request.url else { return nil }

        // Find matching index synchronously
        let matchedIndex: Int? = queue.sync {
            rules.indices.first { i in
                let rule = rules[i]
                guard rule.isEnabled else { return false }
                guard PhantomRuleMatcher.matches(url: url, pattern: rule.rule.urlPattern) else { return false }
                if let requiredMethod = rule.rule.method {
                    guard let requestMethod = request.httpMethod,
                          requestMethod.uppercased() == requiredMethod.uppercased() else { return false }
                }
                return true
            }
        }

        guard let index = matchedIndex else { return nil }

        // Increment hit count asynchronously (non-blocking)
        queue.async(flags: .barrier) {
            self.rules[index].hitCount += 1

            let wrappedRule = self.rules[index]
            let event = RecentEvent(
                ruleID: wrappedRule.id,
                requestURL: url,
                method: request.httpMethod?.uppercased() ?? "GET",
                ruleName: wrappedRule.rule.typeDisplayName,
                actionSummary: wrappedRule.rule.detailDisplayName,
                matchedAt: Date()
            )
            self.recentEvents.insert(event, at: 0)
            if self.recentEvents.count > self.maxRecentEvents {
                self.recentEvents.removeLast(self.recentEvents.count - self.maxRecentEvents)
            }
        }

        return queue.sync { rules[index].rule }
    }
    
    /// Returns all registered rules.
    public func getAll() -> [PhantomInterceptRule] {
        queue.sync {
            return rules
        }
    }

    public struct Snapshot {
        public let totalRules: Int
        public let enabledRules: Int
        public let totalHits: Int
        public let mockoonEnabled: Bool
    }

    public struct RecentEvent: Identifiable {
        public let id: UUID
        public let ruleID: UUID
        public let requestURL: URL
        public let method: String
        public let ruleName: String
        public let actionSummary: String
        public let matchedAt: Date

        public init(ruleID: UUID, requestURL: URL, method: String, ruleName: String, actionSummary: String, matchedAt: Date) {
            self.id = UUID()
            self.ruleID = ruleID
            self.requestURL = requestURL
            self.method = method
            self.ruleName = ruleName
            self.actionSummary = actionSummary
            self.matchedAt = matchedAt
        }
    }

    public func snapshot() -> Snapshot {
        queue.sync {
            Snapshot(
                totalRules: rules.count,
                enabledRules: rules.filter(\.isEnabled).count,
                totalHits: rules.reduce(0) { $0 + $1.hitCount },
                mockoonEnabled: _mockoonConfig.isEnabled
            )
        }
    }

    public func recentEvents(limit: Int = 8) -> [RecentEvent] {
        queue.sync {
            Array(recentEvents.prefix(max(0, limit)))
        }
    }
}
#endif
