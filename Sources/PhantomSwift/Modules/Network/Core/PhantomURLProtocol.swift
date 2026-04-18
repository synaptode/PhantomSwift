#if DEBUG
import Foundation
import PhantomSwiftNetworking

/// Intercepts all network traffic via URLProtocol.
public final class PhantomURLProtocol: URLProtocol {
    private static let requestKey = "com.phantomswift.network.handled"
    private var session: URLSession?
    private var internalTask: URLSessionDataTask?
    private var startTime: Date?
    private var currentRequest: PhantomRequest?
    private var isMockoonRedirect = false

    private var responseBody = Data()
    
    public override class func canInit(with request: URLRequest) -> Bool {
        // Prevent infinite loop
        if URLProtocol.property(forKey: requestKey, in: request) != nil {
            return false
        }
        
        // Only intercept if Network or Interceptor module is enabled
        let features = PhantomSwift.shared.config.environment.enabledFeatures
        guard features.contains(.network) || features.contains(.interceptor) else {
            return false
        }
        
        return true
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: PhantomURLProtocol.requestKey, in: mutableRequest)

        // Apply Mockoon base-URL redirect if enabled (rewrites scheme+host+port, preserves path)
        if let mockoonURL = PhantomInterceptor.shared.mockoonRedirect(for: request.url) {
            mutableRequest.url = mockoonURL
            isMockoonRedirect = true
        }

        // Capture initial request
        self.startTime = Date()
        let requestModel = PhantomRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody
        )
        self.currentRequest = requestModel
        // If Mockoon is active, store the rewritten URL for display in network trace
        if isMockoonRedirect {
            self.currentRequest?.mockoonRedirectedURL = mutableRequest.url
        }
        PhantomRequestStore.shared.add(requestModel)
        PhantomSessionRecorder.shared.record(request: requestModel)
        
        // Interceptor Logic
        if let rule = PhantomInterceptor.shared.rule(for: request) {
            handle(rule: rule, request: mutableRequest as URLRequest)
            return
        }
        
        // Bad Network Simulation
        PhantomNetworkSimulator.shared.process { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                self.updateStatus(.failed(error))
                return
            }
            
            let config = self.cleanConfiguration()
            self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.internalTask = self.session?.dataTask(with: mutableRequest as URLRequest)
            self.internalTask?.resume()
        }
    }
    
    private func cleanConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = config.protocolClasses?.filter { $0 != PhantomURLProtocol.self }
        return config
    }
    
    private func handle(rule: InterceptRule, request: URLRequest) {
        switch rule {
        case .block:
            let error = NSError(domain: "com.phantomswift.interceptor", code: 403, userInfo: [NSLocalizedDescriptionKey: "Request blocked by PhantomSwift"])
            client?.urlProtocol(self, didFailWithError: error)
            updateStatus(.blocked)
            
        case .mockResponse(_, _, let statusCode, let headers, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let body = body {
                client?.urlProtocol(self, didLoad: body)
            }
            client?.urlProtocolDidFinishLoading(self)
            updateStatus(.mocked, responseBody: body, responseStatusCode: statusCode, responseHeaders: headers)
            
        case .delay(_, let seconds):
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                let config = self.cleanConfiguration()
                self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.internalTask = self.session?.dataTask(with: request)
                self.internalTask?.resume()
            }
            
        case .redirect(_, let toURLString):
            if let toURL = URL(string: toURLString) {
                var newRequest = request
                newRequest.url = toURL
                let config = self.cleanConfiguration()
                self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.internalTask = self.session?.dataTask(with: newRequest)
                self.internalTask?.resume()
            } else {
                let error = NSError(
                    domain: "com.phantomswift.interceptor",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URL: \(toURLString)"]
                )
                client?.urlProtocol(self, didFailWithError: error)
                updateStatus(.failed(error))
            }
            
        case .modifyRequest(_, let transform):
            var modifiedRequest = request
            transform(&modifiedRequest)
            let config = self.cleanConfiguration()
            self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.internalTask = self.session?.dataTask(with: modifiedRequest)
            self.internalTask?.resume()
            
        case .mapLocal(_, let fileName):
            if let fileURL = getSandboxURL(for: fileName),
               let data = try? Data(contentsOf: fileURL) {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                updateStatus(.mocked, responseBody: data)
            } else {
                let error = NSError(domain: "com.phantomswift.interceptor", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local file not found: \(fileName)"])
                client?.urlProtocol(self, didFailWithError: error)
                updateStatus(.failed(error))
            }
        }
    }
    
    private func getSandboxURL(for fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func updateStatus(
        _ status: PhantomRequest.RequestStatus,
        responseBody: Data? = nil,
        responseStatusCode: Int? = nil,
        responseHeaders: [String: String] = [:]
    ) {
        if var current = currentRequest {
            current.status = status
            if let body = responseBody {
                // If it's a mock, we already have the body
                let duration = Date().timeIntervalSince(startTime ?? Date())
                current.response = PhantomResponse(
                    statusCode: responseStatusCode ?? 200,
                    headers: responseHeaders,
                    body: body,
                    duration: duration
                )
            }
            PhantomRequestStore.shared.update(current)
        }
    }
    
    public override func stopLoading() {
        internalTask?.cancel()
        internalTask = nil
        session = nil
    }
}

extension PhantomURLProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        if let httpResponse = response as? HTTPURLResponse, var current = currentRequest {
            let duration = Date().timeIntervalSince(startTime ?? Date())
            current.response = PhantomResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                body: nil,
                duration: duration
            )
            // Mockoon requests are still real HTTP calls but to a local mock server → mark as mocked
            current.status = isMockoonRedirect ? .mocked : .completed
            self.currentRequest = current
            PhantomRequestStore.shared.update(current)
        }
        
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
        responseBody.append(data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            if var current = currentRequest {
                current.status = .failed(error)
                PhantomRequestStore.shared.update(current)
            }
        } else {
            client?.urlProtocolDidFinishLoading(self)
            // Update request with full response body
            if var current = currentRequest, let response = current.response {
                current.response = PhantomResponse(
                    statusCode: response.statusCode,
                    headers: response.headers,
                    body: responseBody,
                    duration: response.duration
                )
                PhantomRequestStore.shared.update(current)
            }
        }
    }
}
#endif
