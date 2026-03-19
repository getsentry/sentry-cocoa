@_spi(Private) @testable import Sentry
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

    func testInit_withBinaryContentType_shouldCreateArtificialString() {
        // -- Arrange --
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        let contentType = "image/png"

        // -- Act --
        let body = Body(data: binaryData, contentType: contentType)

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertTrue(string.hasPrefix("[Body not captured"))
            XCTAssertTrue(string.contains("8 bytes"))
            XCTAssertTrue(string.contains("image/png"))
        } else {
            XCTFail("Expected .text content with binary description")
        }

        let result = body?.serialize()
        if let bodyString = result?["body"] as? String {
            XCTAssertTrue(bodyString.hasPrefix("[Body not captured"))
        } else {
            XCTFail("Expected body to be a string with binary data prefix")
        }
    }

    func testInit_withNilContentType_shouldCreatePlaceholder() {
        // -- Arrange --
        let data = Data([0x00, 0x01, 0x02, 0x03])

        // -- Act --
        let body = Body(data: data, contentType: nil)

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertTrue(string.hasPrefix("[Body not captured"))
            XCTAssertTrue(string.contains("4 bytes"))
            XCTAssertTrue(string.contains("unknown"))
        } else {
            XCTFail("Expected .text content with placeholder description")
        }
    }

    func testInit_withUnrecognizedContentType_shouldCreatePlaceholder() {
        // -- Arrange --
        let data = Data("some data".utf8)

        // -- Act --
        let body = Body(data: data, contentType: "application/x-custom-format")

        // -- Assert --
        XCTAssertNotNil(body)
        if case .text(let string) = body?.content {
            XCTAssertTrue(string.hasPrefix("[Body not captured"))
            XCTAssertTrue(string.contains("application/x-custom-format"))
            XCTAssertTrue(string.contains("9 bytes"))
        } else {
            XCTFail("Expected .text content with placeholder description")
        }
    }
    
    // MARK: - Form URL-Encoded Parsing

    func testInit_withFormURLEncoded_shouldParseAsForm() {
        // -- Arrange --
        let formString = "key1=value1&key2=value2&key3=value%20with%20spaces"
        guard let bodyData = formString.data(using: .utf8) else {
            return XCTFail("Failed to create form data")
        }

        // -- Act --
        let body = Body(data: bodyData, contentType: "application/x-www-form-urlencoded")

        // -- Assert --
        if case .json(let value) = body?.content {
            let dict = value as? [String: String]
            XCTAssertEqual(dict?["key1"], "value1")
            XCTAssertEqual(dict?["key2"], "value2")
            XCTAssertEqual(dict?["key3"], "value with spaces")
        } else {
            XCTFail("Expected .json content for form data")
        }
    }

    func testInit_withFormURLEncoded_duplicateKeys_shouldPromoteToArray() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "color=red&color=blue&color=green".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["color"] as? [String], ["red", "blue", "green"])
    }

    func testInit_withFormURLEncoded_emptyValue_shouldParseAsEmptyString() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "key1=&key2=value2".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["key1"] as? String, "")
        XCTAssertEqual(dict["key2"] as? String, "value2")
    }

    func testInit_withFormURLEncoded_missingEquals_shouldFallbackToText() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "key1=value1&malformed&key2=value2".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let serialized = body.serialize()
        let text = try XCTUnwrap(serialized["body"] as? String)
        XCTAssertEqual(text, "key1=value1&malformed&key2=value2")
        let warnings = try XCTUnwrap(serialized["warnings"] as? [String])
        XCTAssertTrue(warnings.contains("BODY_PARSE_ERROR"))
    }

    func testInit_withFormURLEncoded_emptyKeys_shouldBeSkipped() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "=value1&key2=value2".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertNil(dict[""])
        XCTAssertEqual(dict["key2"] as? String, "value2")
    }

    func testInit_withFormURLEncoded_equalsInValue_shouldPreserve() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "query=a=1&token=abc".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["query"] as? String, "a=1")
        XCTAssertEqual(dict["token"] as? String, "abc")
    }

    func testInit_withFormURLEncoded_plusAsSpace_shouldDecode() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: "greeting=hello+world&name=Jane+Doe".data(using: .utf8)!,
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["greeting"] as? String, "hello world")
        XCTAssertEqual(dict["name"] as? String, "Jane Doe")
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

    func testSerialize_withNoContentType_shouldCreatePlaceholder() {
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
        let bodyString = result?["body"] as? String
        XCTAssertTrue(bodyString?.hasPrefix("[Body not captured") == true)
    }

    // MARK: - parseMimeAndEncoding

    func testParseMimeAndEncoding_shouldHandleEdgeCases() {
        // nil → nil mime, UTF-8 default
        let (nilMime, nilEnc) = Body.parseMimeAndEncoding(from: nil)
        XCTAssertNil(nilMime)
        XCTAssertEqual(nilEnc, .utf8)

        // No charset → mime only, UTF-8 default
        let (jsonMime, jsonEnc) = Body.parseMimeAndEncoding(from: "application/json")
        XCTAssertEqual(jsonMime, "application/json")
        XCTAssertEqual(jsonEnc, .utf8)

        // Standard format with spaces
        let (stdMime, stdEnc) = Body.parseMimeAndEncoding(from: "text/html; charset=utf-8")
        XCTAssertEqual(stdMime, "text/html")
        XCTAssertEqual(stdEnc, .utf8)

        // No spaces around semicolon
        let (noSpMime, noSpEnc) = Body.parseMimeAndEncoding(from: "text/html;charset=UTF-8")
        XCTAssertEqual(noSpMime, "text/html")
        XCTAssertEqual(noSpEnc, .utf8)

        // Quoted charset value
        let (qMime, qEnc) = Body.parseMimeAndEncoding(from: "text/html; charset=\"utf-8\"")
        XCTAssertEqual(qMime, "text/html")
        XCTAssertEqual(qEnc, .utf8)

        // ISO-8859-1 charset
        let (isoMime, isoEnc) = Body.parseMimeAndEncoding(from: "text/html; charset=iso-8859-1")
        XCTAssertEqual(isoMime, "text/html")
        XCTAssertEqual(isoEnc, .isoLatin1)

        // Non-charset parameter only → UTF-8 default
        let (mpMime, mpEnc) = Body.parseMimeAndEncoding(from: "multipart/form-data; boundary=----WebKitFormBoundary")
        XCTAssertEqual(mpMime, "multipart/form-data")
        XCTAssertEqual(mpEnc, .utf8)

        // Multiple params — charset extracted correctly
        let (multiMime, multiEnc) = Body.parseMimeAndEncoding(from: "application/json; charset=utf-8; boundary=something")
        XCTAssertEqual(multiMime, "application/json")
        XCTAssertEqual(multiEnc, .utf8)

        // Completely malformed → returned as-is, UTF-8 default
        let (badMime, badEnc) = Body.parseMimeAndEncoding(from: "totally-not-a-content-type")
        XCTAssertEqual(badMime, "totally-not-a-content-type")
        XCTAssertEqual(badEnc, .utf8)

        // Unrecognized charset name → UTF-8 fallback
        let (unkMime, unkEnc) = Body.parseMimeAndEncoding(from: "text/html; charset=made-up-encoding")
        XCTAssertEqual(unkMime, "text/html")
        XCTAssertEqual(unkEnc, .utf8)

        // Empty string → nil mime, UTF-8 default
        let (emptyMime, emptyEnc) = Body.parseMimeAndEncoding(from: "")
        XCTAssertNil(emptyMime)
        XCTAssertEqual(emptyEnc, .utf8)
    }
}
