@_spi(Private) @testable import Sentry
import XCTest

final class SentryLogClientReportTests: XCTestCase {

    private func makeLog(body: String, attributes: [String: SentryLog.Attribute] = [:]) -> SentryLog {
        SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_234_567_890),
            traceId: SentryId.empty,
            level: .info,
            body: body,
            attributes: attributes
        )
    }

    func testSerializedByteCount_MatchesEncodedPayloadSize() throws {
        // -- Arrange --
        let log = makeLog(
            body: "Test log message",
            attributes: ["user_id": SentryLog.Attribute(string: "12345")]
        )
        let expected = try encodeToJSONData(data: log).count

        // -- Act --
        let byteCount = SentryLogClientReport.serializedByteCount(for: log)

        // -- Assert --
        XCTAssertEqual(byteCount, UInt(expected))
    }

    func testSerializedByteCount_IsGreaterThanZero() {
        // -- Arrange --
        let log = makeLog(body: "hello")

        // -- Act --
        let byteCount = SentryLogClientReport.serializedByteCount(for: log)

        // -- Assert --
        XCTAssertGreaterThan(byteCount, 0)
    }

    func testSerializedByteCount_LargerBodyProducesLargerCount() {
        // -- Arrange --
        let small = makeLog(body: "a")
        let large = makeLog(body: String(repeating: "a", count: 1_000))

        // -- Act --
        let smallCount = SentryLogClientReport.serializedByteCount(for: small)
        let largeCount = SentryLogClientReport.serializedByteCount(for: large)

        // -- Assert --
        XCTAssertGreaterThan(largeCount, smallCount)
    }

    func testSerializedByteCount_AttributesIncreaseCount() {
        // -- Arrange --
        let withoutAttributes = makeLog(body: "same body")
        let withAttributes = makeLog(
            body: "same body",
            attributes: ["key": SentryLog.Attribute(string: "some value")]
        )

        // -- Act --
        let withoutCount = SentryLogClientReport.serializedByteCount(for: withoutAttributes)
        let withCount = SentryLogClientReport.serializedByteCount(for: withAttributes)

        // -- Assert --
        XCTAssertGreaterThan(withCount, withoutCount)
    }

    func testSerializedByteCount_WhenEncodingFails_ReturnsDefault() {
        // -- Arrange --
        // `Double.infinity` has no JSON representation, so JSONEncoder (with its default
        // non-conforming-float strategy) throws while encoding the attribute. This drives
        // serializedByteCount into its error path, where it logs and returns the default byte count.
        let log = makeLog(body: "log", attributes: ["value": SentryLog.Attribute(double: .infinity)])

        // -- Act --
        let byteCount = SentryLogClientReport.serializedByteCount(for: log)

        // -- Assert --
        // The default approximates the size of a typical enriched log (see SentryLogClientReport).
        XCTAssertEqual(byteCount, 512)
    }
}
