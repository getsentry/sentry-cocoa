import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCBridge
import SentryObjCTypes
import XCTest

final class SentryObjCBridgeMetricConversionTests: XCTestCase {

    func testMetricToObjC_shouldIncludeAllProperties() throws {
        // -- Arrange --
        let metric = originalMetric()

        // -- Act --
        let result = metric.toObjC()

        // -- Assert --
        XCTAssertEqual(result.timestamp, metric.timestamp)
        XCTAssertEqual(result.name, metric.name)
        XCTAssertEqual(result.traceId, metric.traceId)
        XCTAssertEqual(result.spanId, try XCTUnwrap(metric.spanId))
        XCTAssertEqual(result.value.type, .distribution)
        XCTAssertEqual(result.value.distributionValue, 4.25, accuracy: 0.001)
        XCTAssertEqual(result.unit, "millisecond")
        XCTAssertEqual(result.attributes["source"]?.stringValue, "swift")
    }

    func testMetricToSwift_shouldIncludeAllProperties() throws {
        // -- Arrange --
        let timestamp = Date(timeIntervalSince1970: 123)
        let traceId = SentryId(uuidString: "12345678123456781234567812345678")
        let spanId = SpanId(value: "8765432112345678")
        let metric = SentryObjCMetric(
            timestamp: timestamp,
            name: "updated.metric",
            trace: traceId,
            spanId: spanId,
            value: SentryObjCMetricValue.gauge(withValue: 5.5),
            unit: "second",
            attributes: [
                "source": SentryObjCAttributeContent.string(withValue: "objc")
            ]
        )

        // -- Act --
        let result = metric.toSwift()

        // -- Assert --
        XCTAssertEqual(result.timestamp, timestamp)
        XCTAssertEqual(result.name, "updated.metric")
        XCTAssertEqual(result.traceId, traceId)
        XCTAssertEqual(result.spanId, spanId)
        XCTAssertEqual(result.value, .gauge(5.5))
        XCTAssertEqual(result.unit, "second")
        XCTAssertEqual(result.attributes["source"]?.anyValue as? String, "objc")
    }

    func testBeforeSendMetric_whenObjCCallbackMutatesMetric_shouldReturnMutatedSwiftMetric() throws {
        // -- Arrange --
        let options = Options()
        let updatedTimestamp = Date(timeIntervalSince1970: 456)
        let updatedTraceId = SentryId(uuidString: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let updatedSpanId = SpanId(value: "aaaaaaaaaaaaaaaa")

        SentrySwiftBridge.bridgeBeforeSendMetric(forOptions: options) { metric in
            metric.timestamp = updatedTimestamp
            metric.name = "callback.metric"
            metric.traceId = updatedTraceId
            metric.spanId = updatedSpanId
            metric.value = SentryObjCMetricValue.counter(withValue: 10)
            metric.unit = "item"
            metric.attributes = [
                "source": SentryObjCAttributeContent.string(withValue: "callback")
            ]

            return metric
        }

        // -- Act --
        let result = try XCTUnwrap(options.beforeSendMetric?(originalMetric()))

        // -- Assert --
        XCTAssertEqual(result.timestamp, updatedTimestamp)
        XCTAssertEqual(result.name, "callback.metric")
        XCTAssertEqual(result.traceId, updatedTraceId)
        XCTAssertEqual(result.spanId, updatedSpanId)
        XCTAssertEqual(result.value, .counter(10))
        XCTAssertEqual(result.unit, "item")
        XCTAssertEqual(result.attributes["source"]?.anyValue as? String, "callback")
    }

    private func originalMetric() -> SentryMetric {
        var metric = SentryMetric(
            timestamp: Date(timeIntervalSince1970: 1),
            traceId: SentryId(uuidString: "550e8400e29b41d4a716446655440000"),
            name: "original.metric",
            value: .distribution(4.25),
            unit: "millisecond",
            attributes: [
                "source": .string("swift")
            ]
        )
        metric.spanId = SpanId(value: "b0e6f15b45c36b12")
        return metric
    }
}
