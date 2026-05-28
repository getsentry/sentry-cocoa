import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatMetricConversionTests: XCTestCase {

    // MARK: - SentryObjCMetric wrapping

    func testMetricWrapping_shouldPreserveAllProperties() {
        // -- Arrange --
        let traceId = SentryId(uuidString: "550e8400e29b41d4a716446655440000")
        let timestamp = Date(timeIntervalSince1970: 123)
        let metric = SentryMetric(
            timestamp: timestamp,
            traceId: traceId,
            name: "test.metric",
            value: .distribution(4.25),
            unit: .millisecond,
            attributes: ["source": .string("swift")]
        )

        // -- Act --
        let objcMetric = SentryObjCMetric(metric)

        // -- Assert --
        XCTAssertEqual(objcMetric.timestamp, timestamp)
        XCTAssertEqual(objcMetric.name, "test.metric")
        XCTAssertTrue(objcMetric.value.isDistribution)
        XCTAssertEqual(objcMetric.value.distributionValue, 4.25, accuracy: 0.001)
    }

    func testMetricWrapping_whenSpanIdSet_shouldPreserveSpanId() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )
        let spanId = SpanId(value: "b0e6f15b45c36b12")
        metric.spanId = spanId

        // -- Act --
        let objcMetric = SentryObjCMetric(metric)

        // -- Assert --
        XCTAssertNotNil(objcMetric.spanId)
    }

    func testMetricWrapping_whenModified_shouldUpdateWrapped() {
        // -- Arrange --
        let objcMetric = SentryObjCMetric(SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "",
            value: .counter(0),
            unit: nil,
            attributes: [:]
        ))
        let newTimestamp = Date(timeIntervalSince1970: 456)

        // -- Act --
        objcMetric.timestamp = newTimestamp
        objcMetric.name = "updated.metric"
        objcMetric.value = SentryObjCMetricValue.gauge(5.5)

        // -- Assert --
        XCTAssertEqual(objcMetric.wrapped.timestamp, newTimestamp)
        XCTAssertEqual(objcMetric.wrapped.name, "updated.metric")
        XCTAssertEqual(objcMetric.wrapped.value, .gauge(5.5))
    }

    // MARK: - SentryObjCMetricValue conversions

    func testMetricValueCounter_shouldRoundTrip() {
        // -- Act --
        let objcValue = SentryObjCMetricValue.counter(42)

        // -- Assert --
        XCTAssertTrue(objcValue.isCounter)
        XCTAssertFalse(objcValue.isGauge)
        XCTAssertFalse(objcValue.isDistribution)
        XCTAssertEqual(objcValue.counterValue, 42)
        XCTAssertEqual(objcValue.toMetricValue(), .counter(42))
    }

    func testMetricValueGauge_shouldRoundTrip() {
        // -- Act --
        let objcValue = SentryObjCMetricValue.gauge(3.14)

        // -- Assert --
        XCTAssertTrue(objcValue.isGauge)
        XCTAssertFalse(objcValue.isCounter)
        XCTAssertFalse(objcValue.isDistribution)
        XCTAssertEqual(objcValue.gaugeValue, 3.14, accuracy: 0.001)
        XCTAssertEqual(objcValue.toMetricValue(), .gauge(3.14))
    }

    func testMetricValueDistribution_shouldRoundTrip() {
        // -- Act --
        let objcValue = SentryObjCMetricValue.distribution(99.9)

        // -- Assert --
        XCTAssertTrue(objcValue.isDistribution)
        XCTAssertFalse(objcValue.isCounter)
        XCTAssertFalse(objcValue.isGauge)
        XCTAssertEqual(objcValue.distributionValue, 99.9, accuracy: 0.001)
        XCTAssertEqual(objcValue.toMetricValue(), .distribution(99.9))
    }

    func testMetricValueCounter_whenAccessingWrongType_shouldReturnDefault() {
        // -- Arrange --
        let objcValue = SentryObjCMetricValue.counter(10)

        // -- Assert --
        XCTAssertEqual(objcValue.gaugeValue, 0)
        XCTAssertEqual(objcValue.distributionValue, 0)
    }

    func testMetricValueGauge_whenAccessingWrongType_shouldReturnDefault() {
        // -- Arrange --
        let objcValue = SentryObjCMetricValue.gauge(1.5)

        // -- Assert --
        XCTAssertEqual(objcValue.counterValue, 0)
        XCTAssertEqual(objcValue.distributionValue, 0)
    }

    // MARK: - SentryObjCAttributeContent conversions

    func testAttributeContentString_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.string("hello")

        // -- Assert --
        XCTAssertEqual(attr.type, "string")
        XCTAssertEqual(attr.value as? String, "hello")
        let converted = attr.toAttributeContent()
        if case .string(let v) = converted {
            XCTAssertEqual(v, "hello")
        } else {
            XCTFail("Expected string attribute")
        }
    }

    func testAttributeContentBoolean_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.boolean(true)

        // -- Assert --
        XCTAssertEqual(attr.type, "boolean")
        XCTAssertEqual(attr.value as? Bool, true)
    }

    func testAttributeContentInteger_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.integer(42)

        // -- Assert --
        XCTAssertEqual(attr.type, "integer")
        XCTAssertEqual(attr.value as? Int, 42)
    }

    func testAttributeContentDouble_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.double(3.14)

        // -- Assert --
        XCTAssertEqual(attr.type, "double")
        XCTAssertEqual(attr.value as? Double, 3.14)
    }

    func testAttributeContentStringArray_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.stringArray(["a", "b"])

        // -- Assert --
        XCTAssertEqual(attr.type, "string[]")
        XCTAssertEqual(attr.value as? [String], ["a", "b"])
    }

    func testAttributeContentBooleanArray_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.booleanArray([true, false])

        // -- Assert --
        XCTAssertEqual(attr.type, "boolean[]")
    }

    func testAttributeContentIntegerArray_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.integerArray([1, 2, 3])

        // -- Assert --
        XCTAssertEqual(attr.type, "integer[]")
    }

    func testAttributeContentDoubleArray_shouldRoundTrip() {
        // -- Act --
        let attr = SentryObjCAttributeContent.doubleArray([1.1, 2.2])

        // -- Assert --
        XCTAssertEqual(attr.type, "double[]")
    }

    // MARK: - SentryObjCUnit conversions

    func testUnitRawValueInit_shouldRoundTrip() {
        // -- Act --
        let unit = SentryObjCUnit(rawValue: "millisecond")

        // -- Assert --
        XCTAssertEqual(unit.rawValue, "millisecond")
    }

    func testUnitStaticProperties_shouldReturnExpectedRawValues() {
        // -- Assert --
        XCTAssertEqual(SentryObjCUnit.nanosecond.rawValue, "nanosecond")
        XCTAssertEqual(SentryObjCUnit.millisecond.rawValue, "millisecond")
        XCTAssertEqual(SentryObjCUnit.second.rawValue, "second")
        XCTAssertEqual(SentryObjCUnit.byte.rawValue, "byte")
        XCTAssertEqual(SentryObjCUnit.kilobyte.rawValue, "kilobyte")
        XCTAssertEqual(SentryObjCUnit.percent.rawValue, "percent")
    }

    func testUnitToSentryUnit_shouldConvertCorrectly() {
        // -- Arrange --
        let objcUnit = SentryObjCUnit.millisecond

        // -- Act --
        let sentryUnit = objcUnit.toSentryUnit()

        // -- Assert --
        XCTAssertEqual(sentryUnit.rawValue, "millisecond")
    }
}
