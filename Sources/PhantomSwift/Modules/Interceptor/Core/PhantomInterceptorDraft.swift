#if DEBUG
import Foundation
import PhantomSwiftNetworking

/// Prefilled rule configuration used to turn captured traffic into interceptor rules quickly.
internal struct PhantomInterceptorDraft {
    internal enum Kind: Equatable {
        case block
        case delay
        case mock
        case redirect
    }

    let kind: Kind
    let urlPattern: String
    var method: String?
    var statusCode: Int?
    var headers: [String: String]
    var bodyText: String?
    var delaySeconds: TimeInterval?
    var redirectDestination: String?

    init(
        kind: Kind,
        urlPattern: String,
        method: String? = nil,
        statusCode: Int? = nil,
        headers: [String: String] = [:],
        bodyText: String? = nil,
        delaySeconds: TimeInterval? = nil,
        redirectDestination: String? = nil
    ) {
        self.kind = kind
        self.urlPattern = urlPattern
        self.method = method
        self.statusCode = statusCode
        self.headers = headers
        self.bodyText = bodyText
        self.delaySeconds = delaySeconds
        self.redirectDestination = redirectDestination
    }

    static func recommendedPattern(for request: PhantomRequest) -> String {
        let path = request.url.path.isEmpty ? "/" : request.url.path
        if let host = request.url.host, !host.isEmpty {
            return "*\(host)\(path)*"
        }
        return "*\(request.url.absoluteString)*"
    }

    static func block(for request: PhantomRequest) -> PhantomInterceptorDraft {
        PhantomInterceptorDraft(kind: .block, urlPattern: recommendedPattern(for: request))
    }

    static func delay(for request: PhantomRequest, seconds: TimeInterval = 2.0) -> PhantomInterceptorDraft {
        PhantomInterceptorDraft(kind: .delay, urlPattern: recommendedPattern(for: request), delaySeconds: seconds)
    }

    static func redirect(for request: PhantomRequest, destination: String? = nil) -> PhantomInterceptorDraft {
        PhantomInterceptorDraft(
            kind: .redirect,
            urlPattern: recommendedPattern(for: request),
            redirectDestination: destination ?? request.url.absoluteString
        )
    }

    static func mock(from request: PhantomRequest, response: PhantomResponse? = nil) -> PhantomInterceptorDraft {
        let sourceResponse = response ?? request.response
        let bodyText: String?
        if let body = sourceResponse?.body {
            bodyText = body.prettyJSON ?? String(data: body, encoding: .utf8) ?? body.base64EncodedString()
        } else {
            bodyText = "{}"
        }

        return PhantomInterceptorDraft(
            kind: .mock,
            urlPattern: recommendedPattern(for: request),
            method: request.method,
            statusCode: sourceResponse?.statusCode ?? 200,
            headers: sourceResponse?.headers ?? [:],
            bodyText: bodyText
        )
    }
}
#endif
