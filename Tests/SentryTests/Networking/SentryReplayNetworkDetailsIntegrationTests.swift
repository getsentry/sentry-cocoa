@_spi(Private) @testable import Sentry
import XCTest

class SentryReplayNetworkDetailsIntegrationTests: XCTestCase {

    private typealias Body = SentryReplayNetworkDetails.Body

    // MARK: - Initialization Tests

    func testInit_withMethod_shouldSetMethod() {
        // -- Arrange & Act --
        let details = SentryReplayNetworkDetails(method: "POST")

        // -- Assert --
        XCTAssertEqual(details.method, "POST")
        XCTAssertNil(details.statusCode)
        XCTAssertNil(details.requestBodySize)
        XCTAssertNil(details.responseBodySize)
    }

    // MARK: - Serialization Tests

    func testSerialize_withFullData_shouldReturnCompleteDictionary() {
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "PUT")

        details.setRequest(
            size: 100,
            body: ["name": "test"],
            allHeaders: ["Content-Type": "application/json", "Authorization": "Bearer token", "Accept": "*/*"],
            configuredHeaders: ["Content-Type", "Authorization"]
        )
        details.setResponse(
            statusCode: 201,
            size: 150,
            body: ["id": 123, "name": "test"],
            allHeaders: ["Content-Type": "application/json", "Cache-Control": "no-cache", "Set-Cookie": "session=123"],
            configuredHeaders: ["Content-Type", "Cache-Control"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
        let expectedJSON = """
        {
            "method": "PUT",
            "statusCode": 201,
            "requestBodySize": 100,
            "responseBodySize": 150,
            "request": {
                "size": 100,
                "headers": {
                    "Authorization": "Bearer token",
                    "Content-Type": "application/json"
                },
                "body": {
                    "body": {
                        "name": "test"
                    }
                }
            },
            "response": {
                "size": 150,
                "headers": {
                    "Cache-Control": "no-cache",
                    "Content-Type": "application/json"
                },
                "body": {
                    "body": {
                        "id": 123,
                        "name": "test"
                    }
                }
            }
        }
        """

        assertJSONEqual(result, expectedJSON: expectedJSON)
    }

    func testSerialize_withPartialData_shouldOnlyIncludeSetFields() {
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "GET")
        details.setResponse(
            statusCode: 404,
            size: nil,
            body: nil,
            allHeaders: ["Cache-Control": "no-cache", "Content-Type": "text/plain", "X-Custom": "value"],
            configuredHeaders: ["Cache-Control", "Content-Type"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
        let expectedJSON = """
        {
            "method": "GET",
            "statusCode": 404,
            "response": {
                "headers": {
                    "Cache-Control": "no-cache",
                    "Content-Type": "text/plain"
                }
            }
        }
        """

        assertJSONEqual(result, expectedJSON: expectedJSON)
    }

    func testSerialize_withHeaderFiltering_shouldOnlyIncludeConfiguredHeaders() {
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "GET")
        details.setRequest(
            size: nil,
            body: nil,
            allHeaders: [
                "Content-Type": "application/json",
                "Authorization": "Bearer secret",
                "X-Internal": "hidden",
                "Cookie": "session=abc"
            ],
            configuredHeaders: ["Content-Type"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
        guard let request = result["request"] as? [String: Any],
              let headers = request["headers"] as? [String: String] else {
            return XCTFail("Expected request with headers")
        }
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertNil(headers["Authorization"])
    }

    // MARK: - Test Helpers

    private func assertJSONEqual(_ result: [String: Any], expectedJSON: String) {
        guard let expectedData = expectedJSON.data(using: .utf8) else {
            return XCTFail("Failed to convert expected JSON string to data")
        }

        do {
            let expectedDict = try JSONSerialization.jsonObject(with: expectedData, options: []) as? NSDictionary
            let actualDict = result as NSDictionary
            XCTAssertEqual(actualDict, expectedDict)
        } catch {
            XCTFail("Failed to parse expected JSON: \(error)")
        }
    }
}
