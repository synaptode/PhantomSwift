#if DEBUG
import Foundation

/// Service to record a sequence of network requests.
public final class PhantomSessionRecorder {
    public static let shared = PhantomSessionRecorder()
    
    public private(set) var isRecording: Bool = false
    public private(set) var recordedRequests: [PhantomRequest] = []
    
    private init() {}
    
    public func startRecording() {
        recordedRequests.removeAll()
        isRecording = true
    }
    
    public func stopRecording() {
        isRecording = false
    }
    
    public func record(request: PhantomRequest) {
        guard isRecording else { return }
        recordedRequests.append(request)
    }
}

/// Service to replay recorded network sessions.
public final class PhantomSessionReplayer {
    public static let shared = PhantomSessionReplayer()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // Ensure replayed requests are NOT intercepted again by ourselves
        config.protocolClasses = config.protocolClasses?.filter { $0 != PhantomURLProtocol.self }
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    /// Replays a list of requests sequentially.
    public func replay(requests: [PhantomRequest], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for request in requests {
            group.enter()
            var urlRequest = URLRequest(url: request.url)
            urlRequest.httpMethod = request.method
            urlRequest.allHTTPHeaderFields = request.headers
            urlRequest.httpBody = request.body
            
            let task = session.dataTask(with: urlRequest) { _, _, _ in
                group.leave()
            }
            task.resume()
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
}
#endif
