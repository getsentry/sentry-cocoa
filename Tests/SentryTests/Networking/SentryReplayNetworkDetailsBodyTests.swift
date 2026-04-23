@_spi(Private) @testable import Sentry
import XCTest

class SentryReplayNetworkDetailsBodyTests: XCTestCase {

    private typealias Body = SentryReplayNetworkDetails.Body

    // MARK: - Initialization Tests

    func testInit_withJSONDictionary_shouldParseCorrectly() throws {
        // -- Arrange --
        let bodyContent: [String: Any] = ["key": "value", "number": 42]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyContent)

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

    func testInit_withJSONArray_shouldParseCorrectly() throws {
        // -- Arrange --
        let bodyContent = ["item1", "item2", "item3"]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyContent)

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
        let bodyData = Data(bodyContent.utf8)

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
        let bodyData = Data(invalidJSON.utf8)

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

    func testInit_withLargeData_shouldTruncate() throws {
        // -- Arrange --
        let largeString = String(repeating: "a", count: 200_000)
        let bodyData = Data(largeString.utf8)

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
        let serialized = try XCTUnwrap(body?.serialize())
        let warningStrings = try XCTUnwrap(serialized["warnings"] as? [String], "Expected warnings to be serialized as string array")
        XCTAssertEqual(warningStrings, ["TEXT_TRUNCATED"])
    }

    func testInit_withBinaryContentType_shouldCreateArtificialString() throws {
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

        let result = try XCTUnwrap(body?.serialize())
        let bodyString = try XCTUnwrap(result["body"] as? String, "Expected body to be a string with binary data prefix")
        XCTAssertTrue(bodyString.hasPrefix("[Body not captured"))
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
        let bodyData = Data(formString.utf8)

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
            data: Data("color=red&color=blue&color=green".utf8),
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["color"] as? [String], ["red", "blue", "green"])
    }

    func testInit_withFormURLEncoded_emptyValue_shouldParseAsEmptyString() throws {
        // -- Act --
        let body = try XCTUnwrap(Body(
            data: Data("key1=&key2=value2".utf8),
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
            data: Data("key1=value1&malformed&key2=value2".utf8),
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
            data: Data("=value1&key2=value2".utf8),
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
            data: Data("query=a=1&token=abc".utf8),
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
            data: Data("greeting=hello+world&name=Jane+Doe".utf8),
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        // -- Assert --
        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        XCTAssertEqual(dict["greeting"] as? String, "hello world")
        XCTAssertEqual(dict["name"] as? String, "Jane Doe")
    }

    func testFormEncoded_malformedPercentEncoding_shouldPreservePlusDecodingAndEquals() throws {
        // %ZZ is invalid percent-encoding → removingPercentEncoding returns nil.
        // The fallback should still preserve +-to-space and = in values.
        let body = try XCTUnwrap(Body(
            data: Data("key=a%ZZ=b&greeting=hello+world".utf8),
            contentType: "application/x-www-form-urlencoded; charset=utf-8"
        ))

        let dict = try XCTUnwrap(body.serialize()["body"] as? [String: Any])
        // Value preserves the joined "=" and the +-to-space conversion on the valid pair
        XCTAssertEqual(dict["key"] as? String, "a%ZZ=b")
        XCTAssertEqual(dict["greeting"] as? String, "hello world")
    }

    // MARK: - Multi-byte Truncation

    func testInit_withTruncatedMultiByteUTF8_shouldRecoverValidPrefix() throws {
        // UTF-8 byte widths:
        //   3-byte chars: CJK (e.g. "你" = E4 BD A0)
        //   4-byte chars: emoji (e.g. "😀" = F0 9F 98 80)
        //   2-byte chars: accented Latin (e.g. "é" = C3 A9)

        // -- dropLast(1): 3-byte char split after 2 bytes --
        // "你好" = 6 bytes; prefix(5) cuts second char after 2 of 3 bytes
        let cjk = Data("你好".utf8)
        XCTAssertEqual(cjk.count, 6)
        let body1 = try XCTUnwrap(Body(data: cjk.prefix(5), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body1.serialize()["body"] as? String, "你")

        // -- dropLast(2): 3-byte char split after 1 byte --
        // prefix(4) cuts second char after 1 of 3 bytes
        let body2 = try XCTUnwrap(Body(data: cjk.prefix(4), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body2.serialize()["body"] as? String, "你")

        // -- dropLast(3): 4-byte emoji split after 1 byte --
        // "A😀" = 1 + 4 = 5 bytes; prefix(2) cuts emoji after 1 of 4 bytes
        let emoji = Data("A😀".utf8)
        XCTAssertEqual(emoji.count, 5)
        let body3 = try XCTUnwrap(Body(data: emoji.prefix(2), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body3.serialize()["body"] as? String, "A")

        // -- no truncation needed: clean boundary --
        // prefix(3) is exactly "你", no bytes to drop
        let body4 = try XCTUnwrap(Body(data: cjk.prefix(3), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body4.serialize()["body"] as? String, "你")

        // -- pure ASCII: never affected --
        let ascii = Data("hello".utf8)
        let body5 = try XCTUnwrap(Body(data: ascii.prefix(3), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body5.serialize()["body"] as? String, "hel")

        // -- 2-byte char split after 1 byte --
        // "Aé" = 1 + 2 = 3 bytes; prefix(2) cuts "é" after 1 of 2 bytes
        let accented = Data("Aé".utf8)
        XCTAssertEqual(accented.count, 3)
        let body6 = try XCTUnwrap(Body(data: accented.prefix(2), contentType: "text/plain; charset=utf-8"))
        XCTAssertEqual(body6.serialize()["body"] as? String, "A")
    }

    // MARK: - Serialization Tests

    func testSerialize_withStringBody_shouldReturnDictionary() {
        // -- Arrange --
        let bodyContent = "test body"
        let bodyData = Data(bodyContent.utf8)
        let body = Body(data: bodyData, contentType: "text/plain")

        // -- Act --
        let result = body?.serialize()

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["body"] as? String, bodyContent)
    }

    func testSerialize_withJSONDictionary_shouldReturnDictionary() throws {
        // -- Arrange --
        let bodyContent: [String: Any] = ["user": "test", "id": 123]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Act --
        let result = try XCTUnwrap(body?.serialize())

        // -- Assert --
        let bodyDict = try XCTUnwrap(result["body"] as? NSDictionary, "Expected body to be NSDictionary")
        XCTAssertEqual(bodyDict["user"] as? String, "test")
        XCTAssertEqual(bodyDict["id"] as? Int, 123)
    }

    func testSerialize_withJSONArray_shouldReturnArray() throws {
        // -- Arrange --
        let bodyContent = ["item1", "item2", "item3"]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyContent)
        let body = Body(data: bodyData, contentType: "application/json")

        // -- Act --
        let result = try XCTUnwrap(body?.serialize())

        // -- Assert --
        let bodyArray = try XCTUnwrap(result["body"] as? NSArray, "Expected body to be NSArray")
        XCTAssertEqual(bodyArray.count, 3)
        XCTAssertEqual(bodyArray[0] as? String, "item1")
    }

    func testSerialize_withNoContentType_shouldCreatePlaceholder() {
        // -- Arrange --
        let bodyContent = "some content"
        let bodyData = Data(bodyContent.utf8)
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
