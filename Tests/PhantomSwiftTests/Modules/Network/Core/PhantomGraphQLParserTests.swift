import XCTest
@testable import PhantomSwift

final class PhantomGraphQLParserTests: XCTestCase {

    func testParseGraphQLQuery() {
        let json = """
        {
            "operationName": "GetUserProfile",
            "query": "query GetUserProfile($id: ID!) { user(id: $id) { id name email } }",
            "variables": { "id": "42" }
        }
        """.data(using: .utf8)!

        let request = PhantomRequest(
            id: UUID(),
            url: URL(string: "https://api.example.com/graphql")!,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: json
        )

        let parsed = PhantomGraphQLParser.parse(request: request)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.operationName, "GetUserProfile")
        XCTAssertEqual(parsed?.operationType, .query)
        XCTAssertEqual(parsed?.displayName, "Query: GetUserProfile")
        XCTAssertNotNil(parsed?.variablesString)
    }

    func testParseGraphQLMutation() {
        let json = """
        {
            "query": "mutation UpdateUser($name: String!) { updateUser(name: $name) { id name } }",
            "variables": { "name": "Alice" }
        }
        """.data(using: .utf8)!

        let request = PhantomRequest(
            id: UUID(),
            url: URL(string: "https://api.example.com/graphql")!,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: json
        )

        let parsed = PhantomGraphQLParser.parse(request: request)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.operationType, .mutation)
        XCTAssertEqual(parsed?.operationName, "UpdateUser")
        XCTAssertEqual(parsed?.displayName, "Mutation: UpdateUser")
    }

    func testParseGraphQLWithErrors() {
        let reqJson = """
        {
            "query": "query Test { item { id } }"
        }
        """.data(using: .utf8)!

        let resJson = """
        {
            "errors": [
                { "message": "Unauthorized access", "locations": [{ "line": 2, "column": 3 }] }
            ],
            "data": null
        }
        """.data(using: .utf8)!

        let response = PhantomResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: resJson,
            duration: 0.12
        )

        var request = PhantomRequest(
            id: UUID(),
            url: URL(string: "https://api.example.com/graphql")!,
            method: "POST",
            headers: [:],
            body: reqJson
        )
        request.response = response
        let parsed = PhantomGraphQLParser.parse(request: request)
        XCTAssertNotNil(parsed)
        XCTAssertTrue(parsed?.hasErrors ?? false)
        XCTAssertEqual(parsed?.errors.count, 1)
        XCTAssertEqual(parsed?.errors.first, "Unauthorized access")
    }

    func testIsGraphQLPath() {
        let req1 = PhantomRequest(
            id: UUID(),
            url: URL(string: "https://api.example.com/graphql")!,
            method: "POST",
            headers: [:],
            body: nil
        )
        XCTAssertTrue(PhantomGraphQLParser.isGraphQL(request: req1))

        let req2 = PhantomRequest(
            id: UUID(),
            url: URL(string: "https://api.example.com/rest/users")!,
            method: "GET",
            headers: [:],
            body: nil
        )
        XCTAssertFalse(PhantomGraphQLParser.isGraphQL(request: req2))
    }

    func testFormatQuery() {
        let raw = "query GetUser { user { id name } }"
        let formatted = PhantomGraphQLParser.formatQuery(raw)
        XCTAssertTrue(formatted.contains("\n"))
    }
}
