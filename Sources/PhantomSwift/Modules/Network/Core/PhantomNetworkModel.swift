#if DEBUG
import Foundation

/// Represents a captured network request.
public struct PhantomRequest: Identifiable {
    public let id: UUID
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data?
    public let timestamp: Date
    
    /// The associated response, if available.
    public var response: PhantomResponse?

    /// Combined status for the request (mocked, blocked, etc.)
    public var status: RequestStatus = .pending

    /// If redirected to a Mockoon server, the rewritten URL (original URL is kept in `url`).
    public var mockoonRedirectedURL: URL?
    
    public enum RequestStatus {
        case pending
        case completed
        case failed(Error)
        case mocked
        case blocked
    }
    
    public init(id: UUID = UUID(),
                url: URL,
                method: String,
                headers: [String: String],
                body: Data?,
                timestamp: Date = Date()) {
        self.id = id
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
    }
}

/// Represents a captured network response.
public struct PhantomResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data?
    public let duration: TimeInterval
    public let timestamp: Date
    
    public init(statusCode: Int,
                headers: [String: String],
                body: Data?,
                duration: TimeInterval,
                timestamp: Date = Date()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.duration = duration
        self.timestamp = timestamp
    }
}
#endif
