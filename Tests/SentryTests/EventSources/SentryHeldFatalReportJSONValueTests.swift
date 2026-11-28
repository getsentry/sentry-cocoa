#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryHeldFatalReportJSONValueTests: XCTestCase {

    func testInit_whenJSONObjectHasEveryKindOfValue_shouldKeepEachWithItsType() throws {
        // -- Arrange --
        let jsonObject: [String: Any] = [
            "string": "value",
            "bool": true,
            "int": 1,
            "negative": -1,
            "uint": UInt64.max,
            "double": 1.5,
            "null": NSNull(),
            "array": ["a", 2, false],
            "object": ["nested": ["key": "value"]]
        ]

        // -- Act --
        let sut = try XCTUnwrap(SentryHeldFatalReport.JSONValue(jsonObject: jsonObject))

        // -- Assert --
        XCTAssertEqual(sut, .object([
            "string": .string("value"),
            "bool": .bool(true),
            "int": .int(1),
            "negative": .int(-1),
            "uint": .uint(UInt64.max),
            "double": .double(1.5),
            "null": .null,
            "array": .array([.string("a"), .int(2), .bool(false)]),
            "object": .object(["nested": .object(["key": .string("value")])])
        ]))
    }

    func testInit_whenNumberIsZeroOrOne_shouldNotTurnItIntoABoolean() {
        // -- Act & Assert --
        XCTAssertEqual(SentryHeldFatalReport.JSONValue(jsonObject: NSNumber(value: 1)), .int(1))
        XCTAssertEqual(SentryHeldFatalReport.JSONValue(jsonObject: NSNumber(value: 0)), .int(0))
        XCTAssertEqual(SentryHeldFatalReport.JSONValue(jsonObject: NSNumber(value: true)), .bool(true))
    }

    func testInit_whenValueIsNotJSON_shouldReturnNil() {
        // -- Act & Assert --
        XCTAssertNil(SentryHeldFatalReport.JSONValue(jsonObject: Date()))
        XCTAssertNil(SentryHeldFatalReport.JSONValue(jsonObject: ["date": Date()]))
        XCTAssertNil(SentryHeldFatalReport.JSONValue(jsonObject: [Data()]))
        XCTAssertNil(SentryHeldFatalReport.JSONValue(jsonObject: Double.nan))
        XCTAssertNil(SentryHeldFatalReport.JSONValue(jsonObject: Double.infinity))
    }

    func testJSONObject_whenEncodedAndDecoded_shouldEqualWhatJSONSerializationReads() throws {
        // -- Arrange --
        let jsonObject: [String: Any] = [
            "string": "value",
            "bool": true,
            "false": false,
            "int": 1,
            "zero": 0,
            "uint": UInt64.max,
            "double": 1.5,
            "null": NSNull(),
            "array": ["a", 2, false, ["key": "value"]],
            "object": ["nested": ["key": 1.25]]
        ]
        let sut = try XCTUnwrap(SentryHeldFatalReport.JSONValue(jsonObject: jsonObject))

        // -- Act --
        let data = try JSONEncoder().encode(sut)
        let decoded = try JSONDecoder().decode(SentryHeldFatalReport.JSONValue.self, from: data)

        // -- Assert --
        XCTAssertEqual(decoded, sut)
        XCTAssertEqual(decoded.jsonObject as? NSDictionary, try JSONSerialization.jsonObject(with: data) as? NSDictionary)
        XCTAssertEqual(decoded.jsonObject as? NSDictionary, jsonObject as NSDictionary)
    }

    func testDecode_whenStringLooksLikeADate_shouldKeepItAString() throws {
        // -- Arrange --
        let data = Data(#"{"started":"2023-11-14T22:13:20.000Z"}"#.utf8)

        // -- Act --
        let sut = try JSONDecoder().decode(SentryHeldFatalReport.JSONValue.self, from: data)

        // -- Assert --
        XCTAssertEqual(sut, .object(["started": .string("2023-11-14T22:13:20.000Z")]))
        XCTAssertEqual((sut.jsonObject as? [String: Any])?["started"] as? String, "2023-11-14T22:13:20.000Z")
    }
}
