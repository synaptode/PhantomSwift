#if DEBUG
import XCTest
@testable import PhantomSwift

final class PhantomCURLExporterTests: XCTestCase {

    func testExport_withURLOnly() {
        let url = URL(string: "https://api.example.com/data")!
        let request = URLRequest(url: url)

        let curlCommand = PhantomCURLExporter.export(from: request)

        XCTAssertEqual(curlCommand, "curl \"https://api.example.com/data\" \\\n  -X GET")
    }

    func testExport_withMethod() {
        let url = URL(string: "https://api.example.com/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let curlCommand = PhantomCURLExporter.export(from: request)

        XCTAssertEqual(curlCommand, "curl \"https://api.example.com/data\" \\\n  -X POST")
    }

    func testExport_withHeaders() {
        let url = URL(string: "https://api.example.com/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer token123", forHTTPHeaderField: "Authorization")

        let curlCommand = PhantomCURLExporter.export(from: request)

        XCTAssertTrue(curlCommand.contains("-H \"Accept: application/json\""))
        XCTAssertTrue(curlCommand.contains("-H \"Authorization: Bearer token123\""))
        XCTAssertTrue(curlCommand.hasPrefix("curl \"https://api.example.com/data\" \\\n  -X GET"))
    }

    func testExport_withEscapedHeaders() {
        let url = URL(string: "https://api.example.com/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("value with \"quotes\"", forHTTPHeaderField: "X-Custom")

        let curlCommand = PhantomCURLExporter.export(from: request)

        XCTAssertTrue(curlCommand.contains("-H \"X-Custom: value with \\\"quotes\\\"\""))
    }

    func testExport_withBody() {
        let url = URL(string: "https://api.example.com/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let jsonString = "{\"key\":\"value\"}"
        request.httpBody = jsonString.data(using: .utf8)

        let curlCommand = PhantomCURLExporter.export(from: request)

        let expectedBodyPart = "-d \"{\\\"key\\\":\\\"value\\\"}\""
        XCTAssertTrue(curlCommand.contains(expectedBodyPart))
        XCTAssertTrue(curlCommand.contains("-X POST"))
    }

    // MARK: - PhantomRequest tests

    func testExportFromPhantomRequest_withHeadersAndBody() {
        let url = URL(string: "https://api.example.com/data")!
        let jsonString = "{\"key\":\"value\"}"
        let bodyData = jsonString.data(using: .utf8)

        let phantomRequest = PhantomRequest(
            url: url,
            method: "POST",
            headers: [
                "Accept": "application/json",
                "X-Custom": "value with \"quotes\""
            ],
            body: bodyData
        )

        let curlCommand = PhantomCURLExporter.export(from: phantomRequest)

        // Headers are sorted alphabetically by key in the implementation
        XCTAssertEqual(
            curlCommand,
            """
            curl "https://api.example.com/data" \\
              -X POST \\
              -H "Accept: application/json" \\
              -H "X-Custom: value with \\"quotes\\"" \\
              -d "{\\"key\\":\\"value\\"}"
            """
        )
    }

    func testExportFromPhantomRequest_withoutBody() {
        let url = URL(string: "https://api.example.com/data")!
        let phantomRequest = PhantomRequest(
            url: url,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil
        )

        let curlCommand = PhantomCURLExporter.export(from: phantomRequest)

        XCTAssertEqual(
            curlCommand,
            """
            curl "https://api.example.com/data" \\
              -X GET \\
              -H "Accept: application/json"
            """
        )
    }
}
#endif
