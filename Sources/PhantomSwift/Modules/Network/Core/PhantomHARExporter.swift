#if DEBUG
import UIKit

/// Exports captured network requests as HAR (HTTP Archive) 1.2 JSON.
/// Compatible with Chrome DevTools, Postman, Proxyman, and Charles Proxy.
internal final class PhantomHARExporter {

    internal static let shared = PhantomHARExporter()
    private init() {}

    // MARK: - Public API

    /// Generates a HAR JSON `Data` from the given requests.
    internal func generateHAR(from requests: [PhantomRequest]) -> Data? {
        let har = buildHAR(requests: requests)
        return try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted, .sortedKeys])
    }

    /// Generates a HAR JSON `Data` from a single request.
    internal func generateHAR(from request: PhantomRequest) -> Data? {
        generateHAR(from: [request])
    }

    /// Presents a share sheet with the HAR file from the given view controller.
    internal func export(from viewController: UIViewController, requests: [PhantomRequest]) {
        guard let data = generateHAR(from: requests) else { return }
        presentShareSheet(viewController: viewController, data: data)
    }

    /// Presents a share sheet with a single request exported as HAR.
    internal func export(from viewController: UIViewController, request: PhantomRequest) {
        guard let data = generateHAR(from: request) else { return }
        presentShareSheet(viewController: viewController, data: data)
    }

    private func presentShareSheet(viewController: UIViewController, data: Data) {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "PhantomSwift_\(formatter.string(from: Date())).har"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
        } catch {
            return
        }

        let activity = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: tempURL)
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                        y: viewController.view.bounds.midY, width: 0, height: 0)
        }

        viewController.present(activity, animated: true)
    }

    // MARK: - HAR Builder

    private func buildHAR(requests: [PhantomRequest]) -> [String: Any] {
        let entries: [[String: Any]] = requests.compactMap { buildEntry($0) }
        let log: [String: Any] = [
            "version": "1.2",
            "creator": [
                "name": "PhantomSwift",
                "version": "1.0.0"
            ],
            "pages": buildPages(requests: requests),
            "entries": entries
        ]
        return ["log": log]
    }

    private func buildPages(requests: [PhantomRequest]) -> [[String: Any]] {
        let earliest = requests.map { $0.timestamp }.min() ?? Date()
        return [[
            "startedDateTime": iso8601(earliest),
            "id": "page_1",
            "title": "PhantomSwift Capture",
            "pageTimings": ["onLoad": -1]
        ]]
    }

    private func buildEntry(_ request: PhantomRequest) -> [String: Any]? {
        let duration = request.response?.duration ?? 0.0

        var entry: [String: Any] = [
            "startedDateTime": iso8601(request.timestamp),
            "time": duration * 1000,
            "request": buildRequest(request),
            "response": buildResponse(request),
            "cache": [:] as [String: Any],
            "timings": [
                "send": 0,
                "wait": duration * 1000,
                "receive": 0
            ],
            "pageref": "page_1"
        ]

        if let mockURL = request.mockoonRedirectedURL {
            entry["comment"] = "Mockoon redirect → \(mockURL.absoluteString)"
        }

        return entry
    }

    private func buildRequest(_ req: PhantomRequest) -> [String: Any] {
        var result: [String: Any] = [
            "method": req.method,
            "url": req.url.absoluteString,
            "httpVersion": "HTTP/1.1",
            "headers": req.headers.map { ["name": $0.key, "value": $0.value] },
            "queryString": buildQueryString(req.url),
            "cookies": [] as [[String: Any]],
            "headersSize": -1,
            "bodySize": req.body?.count ?? 0
        ]

        if let body = req.body {
            let mimeType = req.headers["Content-Type"] ?? "application/octet-stream"
            let text = String(data: body, encoding: .utf8) ?? body.base64EncodedString()
            result["postData"] = [
                "mimeType": mimeType,
                "text": text,
                "params": [] as [[String: Any]]
            ]
        }

        return result
    }

    private func buildResponse(_ req: PhantomRequest) -> [String: Any] {
        guard let resp = req.response else {
            return [
                "status": 0,
                "statusText": "",
                "httpVersion": "HTTP/1.1",
                "headers": [] as [[String: Any]],
                "cookies": [] as [[String: Any]],
                "content": ["size": 0, "mimeType": "text/plain"],
                "redirectURL": "",
                "headersSize": -1,
                "bodySize": 0
            ]
        }

        let bodySize = resp.body?.count ?? 0
        let mimeType = resp.headers["Content-Type"] ?? "application/octet-stream"

        var content: [String: Any] = [
            "size": bodySize,
            "mimeType": mimeType
        ]

        if let body = resp.body {
            if let text = String(data: body, encoding: .utf8) {
                content["text"] = text
            } else {
                content["text"] = body.base64EncodedString()
                content["encoding"] = "base64"
            }
        }

        return [
            "status": resp.statusCode,
            "statusText": httpStatusText(resp.statusCode),
            "httpVersion": "HTTP/1.1",
            "headers": resp.headers.map { ["name": $0.key, "value": $0.value] },
            "cookies": [] as [[String: Any]],
            "content": content,
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": bodySize
        ]
    }

    private func buildQueryString(_ url: URL) -> [[String: String]] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [] }
        return items.map { ["name": $0.name, "value": $0.value ?? ""] }
    }

    // MARK: - Helpers

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default:  return ""
        }
    }
}
#endif
