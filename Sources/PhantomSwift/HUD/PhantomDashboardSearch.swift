#if DEBUG
import Foundation

internal enum PhantomDashboardSearch {
    /// Lower score means a better match. `nil` means no match.
    static func score(query: String, title: String, subtitle: String) -> Int? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }

        let normalizedTitle = normalize(title)
        let normalizedSubtitle = normalize(subtitle)

        if normalizedTitle == normalizedQuery { return 0 }
        if normalizedTitle.hasPrefix(normalizedQuery) { return 1 }
        if normalizedTitle.contains(normalizedQuery) { return 2 }
        if normalizedSubtitle.contains(normalizedQuery) { return 3 }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
