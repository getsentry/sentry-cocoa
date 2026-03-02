@testable import Sentry
import XCTest

class SentryReplayNetworkDetailsBodyTests: XCTestCase {

    private typealias Body = SentryReplayNetworkDetails.Body

    // MARK: - Initialization Tests

    func testInit_withJSONDictionary_shouldParseCorrectly() {
        // -- Arrange --
        let bodyContent: [String: Any] = ["key": "value", "number": 42]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        } catch {
            return XCTFail("Failed to create JSON data: \(error)")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .json(let value) = body?.content {
            let dict = value as? [String: Any]
            XCTAssertEqual(dict?["key"] as? String, "value")
            XCTAssertEqual(dict?["number"] as? Int, 42)
        } else {
            XCTFail("Expected .json content")
        }
    }

    func testInit_withJSONArray_shouldParseCorrectly() {
        // -- Arrange --
        let bodyContent = ["item1", "item2", "item3"]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        } catch {
            return XCTFail("Failed to create JSON data: \(error)")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .json(let value) = body?.content {
            let array = value as? [String]
            XCTAssertEqual(array?.count, 3)
            XCTAssertEqual(array?[0], "item1")
            XCTAssertEqual(array?[1], "item2")
            XCTAssertEqual(array?[2], "item3")
        } else {
            XCTFail("Expected .json content")
        }
    }

    func testInit_withTextData_shouldStoreAsString() {
        // -- Arrange --
        let bodyContent = "This is plain text content"
        guard let bodyData = bodyContent.data(using: .utf8) else {
            return XCTFail("Failed to create text data")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "text/plain")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertEqual(string, bodyContent)
        } else {
            XCTFail("Expected .text content")
        }
    }

    func testInit_withEmptyData_shouldReturnNil() {
        // -- Act --
        let body = Body(data: Data(), contentType: "application/json")

        // -- Assert --
        XCTAssertNil(body)
    }

    func testInit_withFormURLEncoded_shouldParseAsForm() {
        // -- Arrange --
        let formString = "key1=value1&key2=value2&key3=value%20with%20spaces"
        guard let bodyData = formString.data(using: .utf8) else {
            return XCTFail("Failed to create form data")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "application/x-www-form-urlencoded")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .json(let value) = body?.content {
            let dict = value as? [String: String]
            XCTAssertEqual(dict?["key1"], "value1")
            XCTAssertEqual(dict?["key2"], "value2")
            XCTAssertEqual(dict?["key3"], "value with spaces")
        } else {
            XCTFail("Expected .json content for form data")
        }
    }

    func testInit_withInvalidJSON_shouldFallbackToString() {
        // -- Arrange --
        let invalidJSON = "{ invalid json }"
        guard let bodyData = invalidJSON.data(using: .utf8) else {
            return XCTFail("Failed to create data")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertEqual(string, invalidJSON)
        } else {
            XCTFail("Expected .text fallback for invalid JSON")
        }
        XCTAssertTrue(body?.warnings.contains(.bodyParseError) == true)
    }

    func testInit_withLargeData_shouldTruncate() {
        // -- Arrange --
        let largeString = String(repeating: "a", count: 200_000)
        guard let bodyData = largeString.data(using: .utf8) else {
            return XCTFail("Failed to create large data")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "text/plain")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertLessThanOrEqual(string.count, SentryReplayNetworkDetails.maxBodySize)
        } else {
            XCTFail("Expected .text content")
        }

        XCTAssertTrue(body?.warnings.contains(.textTruncated) == true)

        // Check serialized warnings
        let serialized = body?.serialize()
        if let warningStrings = serialized?["warnings"] as? [String] {
            XCTAssertEqual(warningStrings, ["TEXT_TRUNCATED"])
        } else {
            XCTFail("Expected warnings to be serialized as string array")
        }
    }

    // MARK: - Serialization Tests

    func testSerialize_withStringBody_shouldReturnDictionary() {
        // -- Arrange --
        let bodyContent = "test body"
        guard let bodyData = bodyContent.data(using: .utf8) else {
            return XCTFail("Failed to create data")
        }
        let body = Body(data: bodyData, contentType: "text/plain")

        // -- Act --
        let result = body?.serialize()

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["body"] as? String, bodyContent)
    }

    func testSerialize_withJSONDictionary_shouldReturnDictionary() {
        // -- Arrange --
        let bodyContent: [String: Any] = ["user": "test", "id": 123]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        } catch {
            return XCTFail("Failed to create JSON data: \(error)")
        }
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Act --
        let result = body?.serialize()

        // -- Assert --
        XCTAssertNotNil(result)
        guard let bodyDict = result?["body"] as? NSDictionary else {
            return XCTFail("Expected body to be NSDictionary")
        }
        XCTAssertEqual(bodyDict["user"] as? String, "test")
        XCTAssertEqual(bodyDict["id"] as? Int, 123)
    }

    func testSerialize_withJSONArray_shouldReturnArray() {
        // -- Arrange --
        let bodyContent = ["item1", "item2", "item3"]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        } catch {
            return XCTFail("Failed to create JSON data: \(error)")
        }
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Act --
        let result = body?.serialize()

        // -- Assert --
        XCTAssertNotNil(result)
        guard let bodyArray = result?["body"] as? NSArray else {
            return XCTFail("Expected body to be NSArray")
        }
        XCTAssertEqual(bodyArray.count, 3)
        XCTAssertEqual(bodyArray[0] as? String, "item1")
    }

    func testSerialize_withNoContentType_shouldDefaultToText() {
        // -- Arrange --
        let bodyContent = "some content"
        guard let bodyData = bodyContent.data(using: .utf8) else {
            return XCTFail("Failed to create data")
        }
        let body = Body(data: bodyData, contentType: nil)

        // -- Act --
        let result = body?.serialize()

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["body"] as? String, bodyContent)
    }
}
