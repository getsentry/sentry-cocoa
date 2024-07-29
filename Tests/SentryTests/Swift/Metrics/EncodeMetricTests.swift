@testable import Sentry
import SentryTestUtils
import XCTest

final class EncodeMetricTests: XCTestCase {

    func testEncodeCounterMetricWithoutTags() {
        let counterMetric = CounterMetric(first: 1.0, key: "app.start", unit: .none, tags: [:])

        let data = encodeToStatsd(flushableBuckets: [12_345: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@:1.0|c|T12345\n")
    }
    
    func testEncodeGaugeMetricWithOneTag() {
        let metric = GaugeMetric(first: 0.0, key: "app.start", unit: .none, tags: ["key": "value"])
        metric.add(value: 5.0)
        metric.add(value: 4.0)
        metric.add(value: 3.0)
        metric.add(value: 2.0)
        metric.add(value: 1.0)

        let data = encodeToStatsd(flushableBuckets: [12_345: [metric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@:1.0:0.0:5.0:15.0:6|g|#key:value|T12345\n")
    }
    
    func testEncodeDistributionMetricWithOutTags() {
        let metric = DistributionMetric(first: 0.0, key: "app.start", unit: .none, tags: [:])
        metric.add(value: 5.12)
        metric.add(value: 1.0)

        let data = encodeToStatsd(flushableBuckets: [12_345: [metric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@:0.0:5.12:1.0|d|T12345\n")
    }
    
    func testEncodeSetMetricWithOutTags() {
        let metric = SetMetric(first: 0, key: "app.start", unit: .none, tags: [:])
        metric.add(value: 0)
        metric.add(value: 1)
        metric.add(value: 1)

        let data = encodeToStatsd(flushableBuckets: [12_345: [metric]])

        let statsd = data.decodeStatsd()
        XCTAssert(statsd.contains("app.start@:"))
        XCTAssert(statsd.contains("|s|T12345\n"))
        
        // the set is unordered, so we have to check for both
        XCTAssert(statsd.contains("1:0") || statsd.contains("0:1"), "statsd expected to contain either '1:0' or '0:1' for the set metric values")
    }

    func testEncodeCounterMetricWithFractionalPart() {
        let counterMetric = CounterMetric(first: 1.123456, key: "app.start", unit: MeasurementUnitDuration.second, tags: [:])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@second:1.123456|c|T10234\n")
    }

    func testEncodeCounterMetricWithOneTag() {
        let counterMetric = CounterMetric(first: 10.1, key: "app.start", unit: MeasurementUnitDuration.second, tags: ["key": "value"])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@second:10.1|c|#key:value|T10234\n")
    }

    func testEncodeCounterMetricWithTwoTags() {
        let counterMetric = CounterMetric(first: 10.1, key: "app.start", unit: MeasurementUnitDuration.second, tags: ["key1": "value1", "key2": "value2"])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]]).decodeStatsd()
        XCTAssert(data.hasPrefix("app.start@second:10.1|c|"))
        XCTAssert(data.hasSuffix("|T10234\n"))
        XCTAssert(data.contains("key1:value1"))
        XCTAssert(data.contains("key2:value2"))
    }

    func testEncodeCounterMetricWithKeyToSanitize() {
        let counterMetric = CounterMetric(first: 10.1, key: "abyzABYZ09_/.-!@a#$Äa", unit: MeasurementUnitDuration.second, tags: [:])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "abyzABYZ09__.-_a_a@second:10.1|c|T10234\n")
    }

    func testEncodeCounterMetricWithTagKeyToSanitize() {
        let counterMetric = CounterMetric(first: 10.1, key: "app.start", unit: MeasurementUnitDuration.second, tags: ["abcABC123_-./äöü$%&abcABC123": "value"])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@second:10.1|c|#abcABC123_-./abcABC123:value|T10234\n")
    }

    func testEncodeCounterMetricWithTagValueToSanitize() {
        let counterMetric = CounterMetric(first: 10.1, key: "app.start", unit: MeasurementUnitDuration.second, tags: ["key": "abc\n\r\t|,\\123"])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssert(data.decodeStatsd().contains(#"abc\\n\\r\\t\\u{7c}\\u{2c}\\\\123"#))
    }
    
    func testEncodeCounterMetricWithUnitToSanitize() {
        let counterMetric = CounterMetric(first: 10.1, key: "app.start", unit: MeasurementUnit(unit: "abyzABYZ09_/.ä"), tags: [:])

        let data = encodeToStatsd(flushableBuckets: [10_234: [counterMetric]])

        XCTAssertEqual(data.decodeStatsd(), "app.start@abyzABYZ09_:10.1|c|T10234\n")
    }
}

private extension Data {
    func decodeStatsd() -> String {
        return String(data: self, encoding: .utf8) ?? ""
    }
}
