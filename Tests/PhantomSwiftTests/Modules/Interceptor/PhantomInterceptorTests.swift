#if DEBUG
import XCTest
@testable import PhantomSwift

final class PhantomInterceptorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any existing rules before each test
        PhantomInterceptor.shared.clear()
        PhantomInterceptor.shared.resetHitCounts()
    }

    override func tearDown() {
        PhantomInterceptor.shared.clear()
        super.tearDown()
    }

    func testRuleForRequest_NoRules_ReturnsNil() {
        // Arrange
        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // Act
        let rule = PhantomInterceptor.shared.rule(for: request)

        // Assert
        XCTAssertNil(rule)
    }

    func testRuleForRequest_MatchingRule_ReturnsRuleAndIncrementsHitCount() {
        // Arrange
        let mockRule = InterceptRule.block(urlPattern: "*/users*")
        PhantomInterceptor.shared.add(rule: mockRule)

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // Wait a tiny bit for the async add to complete
        let exp = expectation(description: "wait")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        // Act
        let returnedRule = PhantomInterceptor.shared.rule(for: request)

        // Assert
        XCTAssertNotNil(returnedRule)
        if case .block(let pattern) = returnedRule {
            XCTAssertEqual(pattern, "*/users*")
        } else {
            XCTFail("Expected .block rule")
        }

        // Verify hit count incremented
        let exp2 = expectation(description: "wait hit count")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)

        let allRules = PhantomInterceptor.shared.getAll()
        XCTAssertEqual(allRules.first?.hitCount, 1)
    }

    func testRuleForRequest_DisabledRule_ReturnsNil() {
        // Arrange
        let mockRule = InterceptRule.block(urlPattern: "*/users*")
        PhantomInterceptor.shared.add(rule: mockRule)

        // Wait for add
        let exp1 = expectation(description: "wait add")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        let allRules = PhantomInterceptor.shared.getAll()
        guard let firstRuleId = allRules.first?.id else {
            XCTFail("Rule not added")
            return
        }

        // Disable the rule
        PhantomInterceptor.shared.toggle(id: firstRuleId)

        // Wait for toggle
        let exp2 = expectation(description: "wait toggle")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1.0)

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // Act
        let returnedRule = PhantomInterceptor.shared.rule(for: request)

        // Assert
        XCTAssertNil(returnedRule)
    }

    func testRuleForRequest_WithMethodRequirement_MatchesMethod() {
        // Arrange
        let mockRule = InterceptRule.mockResponse(urlPattern: "*/posts*", method: "POST", statusCode: 200, headers: [:], body: nil)
        PhantomInterceptor.shared.add(rule: mockRule)

        // Wait for add
        let exp1 = expectation(description: "wait add")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        var getRequest = URLRequest(url: URL(string: "https://api.example.com/posts")!)
        getRequest.httpMethod = "GET"

        var postRequest = URLRequest(url: URL(string: "https://api.example.com/posts")!)
        postRequest.httpMethod = "POST"

        // Act & Assert
        XCTAssertNil(PhantomInterceptor.shared.rule(for: getRequest), "Should not match GET request")
        XCTAssertNotNil(PhantomInterceptor.shared.rule(for: postRequest), "Should match POST request")
    }

    func testRuleForRequest_CaseInsensitiveMethodMatch() {
        // Arrange
        let mockRule = InterceptRule.mockResponse(urlPattern: "*/posts*", method: "post", statusCode: 200, headers: [:], body: nil)
        PhantomInterceptor.shared.add(rule: mockRule)

        // Wait for add
        let exp1 = expectation(description: "wait add")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        var postRequest = URLRequest(url: URL(string: "https://api.example.com/posts")!)
        postRequest.httpMethod = "POST"

        // Act
        let returnedRule = PhantomInterceptor.shared.rule(for: postRequest)

        // Assert
        XCTAssertNotNil(returnedRule, "Should match post request case insensitively")
    }

    func testRuleForRequest_MultipleMatches_ReturnsFirst() {
        // Arrange
        let rule1 = InterceptRule.block(urlPattern: "*/api/*")
        let rule2 = InterceptRule.delay(urlPattern: "*/api/users*", seconds: 5.0)

        PhantomInterceptor.shared.add(rule: rule1)
        PhantomInterceptor.shared.add(rule: rule2)

        // Wait for add
        let exp1 = expectation(description: "wait add")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        let request = URLRequest(url: URL(string: "https://api.example.com/api/users")!)

        // Act
        let returnedRule = PhantomInterceptor.shared.rule(for: request)

        // Assert
        XCTAssertNotNil(returnedRule)
        if case .block(let pattern) = returnedRule {
            XCTAssertEqual(pattern, "*/api/*")
        } else {
            XCTFail("Expected .block rule")
        }
    }
}
#endif
