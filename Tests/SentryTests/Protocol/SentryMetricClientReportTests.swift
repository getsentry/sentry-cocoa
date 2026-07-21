@_spi(Private) @testable import Sentry
import XCTest

final class SentryMetricClientReportTests: XCTestCase {

    private func makeMetric(name: String, attributes: [String: SentryMetric.Attribute] = [:]) -> SentryMetric {
        SentryMetric(
            timestamp: Date(timeIntervalSince1970: 1_234_567_890),
            traceId: SentryId.empty,
            name: name,
            value: .counter(1),
            unit: nil,
            attributes: attributes
        )
    }

    func testSerializedByteCount_MatchesEncodedPayloadSize() throws {
        // -- Arrange --
        let metric = makeMetric(
            name: "api.response_time",
            attributes: ["endpoint": .string("/users")]
        )
        let expected = try encodeToJSONData(data: metric).count

        // -- Act --
        let byteCount = SentryMetricClientReport.serializedByteCount(for: metric)

        // -- Assert --
        XCTAssertEqual(byteCount, UInt(expected))
    }

    func testSerializedByteCount_IsGreaterThanZero() {
        // -- Arrange --
        let metric = makeMetric(name: "db.query.duration")

        // -- Act --
        let byteCount = SentryMetricClientReport.serializedByteCount(for: metric)

        // -- Assert --
        XCTAssertGreaterThan(byteCount, 0)
    }

    func testSerializedByteCount_LongerNameProducesLargerCount() {
        // -- Arrange --
        let small = makeMetric(name: "a")
        let large = makeMetric(name: String(repeating: "a", count: 1_000))

        // -- Act --
        let smallCount = SentryMetricClientReport.serializedByteCount(for: small)
        let largeCount = SentryMetricClientReport.serializedByteCount(for: large)

        // -- Assert --
        XCTAssertGreaterThan(largeCount, smallCount)
    }

    func testSerializedByteCount_AttributesIncreaseCount() {
        // -- Arrange --
        let withoutAttributes = makeMetric(name: "same.name")
        let withAttributes = makeMetric(
            name: "same.name",
            attributes: ["key": .string("some value")]
        )

        // -- Act --
        let withoutCount = SentryMetricClientReport.serializedByteCount(for: withoutAttributes)
        let withCount = SentryMetricClientReport.serializedByteCount(for: withAttributes)

        // -- Assert --
        XCTAssertGreaterThan(withCount, withoutCount)
    }

    func testSerializedByteCount_WhenEncodingFails_ReturnsDefault() {
        // -- Arrange --
        // `Double.infinity` has no JSON representation, so JSONEncoder (with its default
        // non-conforming-float strategy) throws while encoding the attribute. This drives
        // serializedByteCount into its error path, where it logs and returns the default byte count.
        let metric = makeMetric(name: "metric", attributes: ["value": .double(.infinity)])

        // -- Act --
        let byteCount = SentryMetricClientReport.serializedByteCount(for: metric)

        // -- Assert --
        // The default approximates the size of a typical metric (see SentryMetricClientReport).
        XCTAssertEqual(byteCount, 512)
    }
}
