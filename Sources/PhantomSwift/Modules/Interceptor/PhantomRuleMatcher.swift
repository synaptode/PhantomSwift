#if DEBUG
import Foundation

/// Matches URLs against patterns (exact, wildcard, regex).
public final class PhantomRuleMatcher {
    /// Checks if a URL matches a pattern.
    /// - Parameters:
    ///   - url: The URL to check.
    ///   - pattern: The pattern to match against (e.g., "api.example.com/*").
    /// - Returns: True if it matches.
    public static func matches(url: URL, pattern: String) -> Bool {
        let urlString = url.absoluteString
        
        // Exact match
        if urlString == pattern {
            return true
        }
        
        // Wildcard match
        if pattern.contains("*") {
            let escapedPattern = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            let regex = "^" + escapedPattern + "$"
            return urlString.range(of: regex, options: .regularExpression) != nil
        }
        
        // Basic contains if it's not a full URL
        if urlString.contains(pattern) {
            return true
        }
        
        return false
    }
}
#endif
