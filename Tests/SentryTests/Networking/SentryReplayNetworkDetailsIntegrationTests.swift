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

    func testSerialize_withFullData_shouldReturnCompleteDictionary() throws {
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "PUT")

        let requestBodyData = try JSONSerialization.data(withJSONObject: ["name": "test"])
        details.setRequest(
            size: 100,
            bodyData: requestBodyData,
            contentType: "application/json",
            allHeaders: ["Content-Type": "application/json", "Authorization": "Bearer token", "Accept": "*/*"],
            configuredHeaders: ["Content-Type", "Authorization"]
        )

        let responseBodyData = try JSONSerialization.data(withJSONObject: ["id": 123, "name": "test"])
        details.setResponse(
            statusCode: 201,
            size: 150,
            bodyData: responseBodyData,
            contentType: "application/json",
            allHeaders: ["Content-Type": "application/json", "Cache-Control": "no-cache", "Set-Cookie": "session=123"],
            configuredHeaders: ["Content-Type", "Cache-Control"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
#if SDK_V10
        let expectedAuthorization = "[Filtered]"
#else
        let expectedAuthorization = "Bearer token"
#endif
        let expectedJSON = """
        {
            "method": "PUT",
            "statusCode": 201,
            "requestBodySize": 100,
            "responseBodySize": 150,
            "request": {
                "size": 100,
                "headers": {
                    "Authorization": "\(expectedAuthorization)",
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

    func testSerialize_whenReplaySelectsSensitiveRequestHeaders_shouldFilterValues() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
#else
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "GET")
        details.setRequest(
            size: nil,
            bodyData: nil,
            contentType: nil,
            allHeaders: [
                "Authorization": "Bearer secret",
                "X-Auth-Token": "secret-token",
                "X-API-Key": "api-key",
                "X-Request-Id": "request-id"
            ],
            configuredHeaders: ["Authorization", "X-Auth-Token", "X-API-Key", "X-Request-Id"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
        let request = try XCTUnwrap(result["request"] as? [String: Any])
        XCTAssertEqual(request["headers"] as? [String: String], [
            "Authorization": "[Filtered]",
            "X-API-Key": "[Filtered]",
            "X-Auth-Token": "[Filtered]",
            "X-Request-Id": "request-id"
        ])
#endif
    }

    func testSerialize_whenReplaySelectsCookie_shouldFilterSensitiveValues() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
#else
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "GET")
        details.setRequest(
            size: nil,
            bodyData: nil,
            contentType: nil,
            allHeaders: ["Cookie": "theme=dark; session=secret"],
            configuredHeaders: ["Cookie"]
        )

        // -- Act --
        let result = details.serialize()

        // -- Assert --
        let request = try XCTUnwrap(result["request"] as? [String: Any])
        XCTAssertNil(request["headers"])
        XCTAssertEqual(request["cookies"] as? [String: String], [
            "session": "[Filtered]",
            "theme": "dark"
        ])
#endif
    }

    func testSerialize_withPartialData_shouldOnlyIncludeSetFields() {
        // -- Arrange --
        let details = SentryReplayNetworkDetails(method: "GET")
        details.setResponse(
            statusCode: 404,
            size: nil,
            bodyData: nil,
            contentType: nil,
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
            bodyData: nil,
            contentType: nil,
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
