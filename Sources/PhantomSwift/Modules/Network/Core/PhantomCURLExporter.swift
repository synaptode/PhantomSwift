#if DEBUG
import Foundation

/// Utility to export a URLRequest as a cURL command.
public final class PhantomCURLExporter {
    /// Generates a cURL command for the given URLRequest.
    /// - Parameter request: The URLRequest to export.
    /// - Returns: A string containing the cURL command.
    public static func export(from request: URLRequest) -> String {
        guard let url = request.url else { return "" }
        var parts = ["curl \"\(url.absoluteString)\""]

        if let method = request.httpMethod {
            parts.append("-X \(method)")
        }

        request.allHTTPHeaderFields?.forEach { key, value in
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("-H \"\(key): \(escapedValue)\"")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("-d \"\(escapedBody)\"")
        }

        return parts.joined(separator: " \\\n  ")
    }

    /// Generates a cURL command from a `PhantomRequest`.
    internal static func export(from request: PhantomRequest) -> String {
        var parts = ["curl \"\(request.url.absoluteString)\""]
        parts.append("-X \(request.method)")

        request.headers.sorted(by: { $0.key < $1.key }).forEach { key, value in
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("-H \"\(key): \(escapedValue)\"")
        }

        if let body = request.body, let bodyString = String(data: body, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("-d \"\(escapedBody)\"")
        }

        return parts.joined(separator: " \\\n  ")
    }
}
#endif
