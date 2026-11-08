#if DEBUG
import Foundation
import PhantomSwiftNetworking

/// Defines GraphQL operation types.
public enum PhantomGraphQLOperationType: String {
    case query = "Query"
    case mutation = "Mutation"
    case subscription = "Subscription"
    case unknown = "GraphQL"
}

/// Parsed metadata for a GraphQL request and response.
public struct PhantomGraphQLDetails {
    public let operationType: PhantomGraphQLOperationType
    public let operationName: String?
    public let query: String?
    public let variablesString: String?
    public let errors: [String]
    public let hasErrors: Bool

    public var displayName: String {
        if let name = operationName, !name.isEmpty {
            return "\(operationType.rawValue): \(name)"
        }
        return operationType.rawValue
    }
}

/// Parser for detecting and analyzing GraphQL network requests and responses.
public enum PhantomGraphQLParser {

    /// Determines whether a network request represents a GraphQL transaction.
    public static func isGraphQL(request: PhantomRequest) -> Bool {
        if request.url.path.lowercased().hasSuffix("/graphql") {
            return true
        }

        if let queryItems = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems,
           queryItems.contains(where: { $0.name.lowercased() == "query" }) {
            return true
        }

        guard let body = request.body, !body.isEmpty else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] else {
            return false
        }

        return json["query"] != nil || json["operationName"] != nil
    }

    /// Parses GraphQL query, operation details, and potential response errors from a request.
    public static func parse(request: PhantomRequest) -> PhantomGraphQLDetails? {
        guard isGraphQL(request: request) else { return nil }

        var rawQuery: String?
        var operationName: String?
        var variablesString: String?

        extractFromBody(
            request.body,
            query: &rawQuery,
            operation: &operationName,
            variables: &variablesString
        )

        extractFromURL(request.url, query: &rawQuery, operation: &operationName)

        let opType = detectOperationType(from: rawQuery)
        if operationName == nil, let query = rawQuery {
            operationName = extractOperationName(from: query)
        }

        let errors = parseResponseErrors(from: request.response?.body)

        return PhantomGraphQLDetails(
            operationType: opType,
            operationName: operationName,
            query: rawQuery,
            variablesString: variablesString,
            errors: errors,
            hasErrors: !errors.isEmpty
        )
    }

    private static func extractFromBody(
        _ body: Data?,
        query: inout String?,
        operation: inout String?,
        variables: inout String?
    ) {
        guard let body, !body.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return }

        if let queryValue = json["query"] as? String {
            query = queryValue
        }
        if let opName = json["operationName"] as? String, !opName.isEmpty {
            operation = opName
        }
        if let vars = json["variables"],
           let varsData = try? JSONSerialization.data(withJSONObject: vars, options: [.prettyPrinted]),
           let str = String(data: varsData, encoding: .utf8) {
            variables = str
        }
    }

    private static func extractFromURL(_ url: URL, query: inout String?, operation: inout String?) {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return }
        if query == nil {
            query = items.first(where: { $0.name.lowercased() == "query" })?.value
        }
        if operation == nil {
            operation = items.first(where: { $0.name.lowercased() == "operationname" })?.value
        }
    }

    private static func parseResponseErrors(from body: Data?) -> [String] {
        guard let body, !body.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let errorsArray = json["errors"] as? [Any] else { return [] }

        return errorsArray.compactMap { item in
            if let dict = item as? [String: Any] {
                let msg = dict["message"] as? String ?? "Unknown GraphQL Error"
                if let path = dict["path"] as? [Any] {
                    let pathStr = path.map { "\($0)" }.joined(separator: ".")
                    return "[\(pathStr)] \(msg)"
                }
                return msg
            } else if let str = item as? String {
                return str
            }
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func detectOperationType(from query: String?) -> PhantomGraphQLOperationType {
        guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .unknown
        }

        let lower = query.lowercased()
        if lower.hasPrefix("mutation") {
            return .mutation
        } else if lower.hasPrefix("subscription") {
            return .subscription
        } else if lower.hasPrefix("query") || lower.hasPrefix("{") {
            return .query
        }
        return .unknown
    }

    private static func extractOperationName(from query: String) -> String? {
        let pattern = #"(?:query|mutation|subscription)\s+([A-Za-z0-9_]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = query as NSString
        let results = regex.matches(in: query, options: [], range: NSRange(location: 0, length: nsString.length))

        guard let match = results.first, match.numberOfRanges > 1 else {
            return nil
        }
        return nsString.substring(with: match.range(at: 1))
    }

    /// Formats a minified GraphQL query with basic indentation.
    public static func formatQuery(_ query: String) -> String {
        var result = ""
        var indent = 0
        var inString = false

        for char in query {
            if char == "\"" {
                inString.toggle()
                result.append(char)
            } else if inString {
                result.append(char)
            } else if char == "{" {
                indent += 1
                result.append(" {\n" + String(repeating: "  ", count: indent))
            } else if char == "}" {
                indent = max(0, indent - 1)
                result.append("\n" + String(repeating: "  ", count: indent) + "}")
            } else {
                result.append(char)
            }
        }
        return result
    }
}
#endif
