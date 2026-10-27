import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import SentryTestUtils
import XCTest

final class SentryObjCCompatMetricsApiTests: XCTestCase {

    private var mock = TestMetricsApi()
    private var sut = SentryObjCMetricsApi(TestMetricsApi())

    override func setUp() {
        super.setUp()
        mock = TestMetricsApi()
        sut = SentryObjCMetricsApi(mock)
    }

    // MARK: - count

    func testCountWithOptions_shouldForwardAllOptions() throws {
        // -- Arrange --
        let scope = SentryObjCScope()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let options = SentryObjCMetricOptions()
        options.unit = .millisecond
        options.attributes = ["source": .string("test")]
        options.scope = scope
        options.timestamp = timestamp

        // -- Act --
        sut.count("events", value: 5, options: options)

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        let inv = try XCTUnwrap(mock.countInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "events")
        XCTAssertEqual(inv["value"] as? UInt, 5)
        XCTAssertEqual(inv["unit"] as? String, "millisecond")
        XCTAssertEqual((inv["attributes"] as? [String: Any])?["source"] as? String, "test")
        XCTAssertIdentical(inv["scope"] as? Scope, scope.wrapped)
        XCTAssertEqual(inv["timestamp"] as? Date, timestamp)
    }

    func testCountWithValue_shouldForwardEmptyOptions() throws {
        // -- Act --
        sut.count("events", value: 3)

        // -- Assert --
        let inv = try XCTUnwrap(mock.countInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "events")
        XCTAssertEqual(inv["value"] as? UInt, 3)
        XCTAssertEqual((inv["attributes"] as? [String: Any])?.count, 0)
        XCTAssertNil(inv["unit"])
        XCTAssertNil(inv["scope"])
        XCTAssertNil(inv["timestamp"])
    }

    func testCountWithName_shouldForwardValueOne() throws {
        // -- Act --
        sut.count("events")

        // -- Assert --
        let inv = try XCTUnwrap(mock.countInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "events")
        XCTAssertEqual(inv["value"] as? UInt, 1)
    }

    // MARK: - distribution

    func testDistributionWithOptions_shouldForwardAllOptions() throws {
        // -- Arrange --
        let scope = SentryObjCScope()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let options = SentryObjCMetricOptions()
        options.unit = .millisecond
        options.attributes = ["endpoint": .string("/api")]
        options.scope = scope
        options.timestamp = timestamp

        // -- Act --
        sut.distribution("latency", value: 42.5, options: options)

        // -- Assert --
        let inv = try XCTUnwrap(mock.distributionInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "latency")
        XCTAssertEqual(inv["value"] as? Double, 42.5)
        XCTAssertEqual(inv["unit"] as? String, "millisecond")
        XCTAssertEqual((inv["attributes"] as? [String: Any])?["endpoint"] as? String, "/api")
        XCTAssertIdentical(inv["scope"] as? Scope, scope.wrapped)
        XCTAssertEqual(inv["timestamp"] as? Date, timestamp)
    }

    func testDistributionWithValue_shouldForwardEmptyOptions() throws {
        // -- Act --
        sut.distribution("latency", value: 5.0)

        // -- Assert --
        let inv = try XCTUnwrap(mock.distributionInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "latency")
        XCTAssertEqual(inv["value"] as? Double, 5.0)
        XCTAssertNil(inv["unit"])
        XCTAssertNil(inv["scope"])
        XCTAssertNil(inv["timestamp"])
    }

    // MARK: - gauge

    func testGaugeWithOptions_shouldForwardAllOptions() throws {
        // -- Arrange --
        let scope = SentryObjCScope()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let options = SentryObjCMetricOptions()
        options.unit = .byte
        options.attributes = ["process": .string("main")]
        options.scope = scope
        options.timestamp = timestamp

        // -- Act --
        sut.gauge("memory", value: 1_024.0, options: options)

        // -- Assert --
        let inv = try XCTUnwrap(mock.gaugeInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "memory")
        XCTAssertEqual(inv["value"] as? Double, 1_024.0)
        XCTAssertEqual(inv["unit"] as? String, "byte")
        XCTAssertEqual((inv["attributes"] as? [String: Any])?["process"] as? String, "main")
        XCTAssertIdentical(inv["scope"] as? Scope, scope.wrapped)
        XCTAssertEqual(inv["timestamp"] as? Date, timestamp)
    }

    func testGaugeWithValue_shouldForwardEmptyOptions() throws {
        // -- Act --
        sut.gauge("memory", value: 256.0)

        // -- Assert --
        let inv = try XCTUnwrap(mock.gaugeInvocations.first)
        XCTAssertEqual(inv["name"] as? String, "memory")
        XCTAssertEqual(inv["value"] as? Double, 256.0)
        XCTAssertNil(inv["unit"])
        XCTAssertNil(inv["scope"])
        XCTAssertNil(inv["timestamp"])
    }

    #if !SDK_V10
    // MARK: - Deprecated count

    func testCountWithKeyValueAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.count(key: "events", value: 5, attributes: ["source": .string("test")])

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        let inv = mock.countInvocations.first
        XCTAssertEqual(inv?["name"] as? String, "events")
        XCTAssertEqual(inv?["value"] as? UInt, 5)
    }

    func testCountWithKeyValue_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.count(key: "events", value: 3)

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?["name"] as? String, "events")
        XCTAssertEqual(mock.countInvocations.first?["value"] as? UInt, 3)
    }

    func testCountWithKey_shouldForwardWithValueOneAndEmptyAttributes() {
        // -- Act --
        sut.count(key: "events")

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?["name"] as? String, "events")
        XCTAssertEqual(mock.countInvocations.first?["value"] as? UInt, 1)
    }

    // MARK: - Deprecated distribution

    func testDistributionWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.distribution(key: "latency", value: 42.5, unit: .millisecond, attributes: ["endpoint": .string("/api")])

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        let inv = mock.distributionInvocations.first
        XCTAssertEqual(inv?["name"] as? String, "latency")
        XCTAssertEqual(inv?["value"] as? Double, 42.5)
        XCTAssertEqual(inv?["unit"] as? String, "millisecond")
    }

    func testDistributionWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.distribution(key: "latency", value: 10.0, unit: .second)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?["name"] as? String, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?["value"] as? Double, 10.0)
        XCTAssertEqual(mock.distributionInvocations.first?["unit"] as? String, "second")
    }

    func testDistributionWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.distribution(key: "latency", value: 5.0)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?["name"] as? String, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?["value"] as? Double, 5.0)
        XCTAssertNil(mock.distributionInvocations.first?["unit"])
    }

    // MARK: - Deprecated gauge

    func testGaugeWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.gauge(key: "memory", value: 1_024.0, unit: .byte, attributes: ["process": .string("main")])

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        let inv = mock.gaugeInvocations.first
        XCTAssertEqual(inv?["name"] as? String, "memory")
        XCTAssertEqual(inv?["value"] as? Double, 1_024.0)
        XCTAssertEqual(inv?["unit"] as? String, "byte")
    }

    func testGaugeWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.gauge(key: "memory", value: 512.0, unit: .megabyte)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?["name"] as? String, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?["value"] as? Double, 512.0)
        XCTAssertEqual(mock.gaugeInvocations.first?["unit"] as? String, "megabyte")
    }

    func testGaugeWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.gauge(key: "memory", value: 256.0)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?["name"] as? String, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?["value"] as? Double, 256.0)
        XCTAssertNil(mock.gaugeInvocations.first?["unit"])
    }

    // MARK: - Deprecated nil unit

    func testDistributionWithNilUnit_shouldForwardNil() {
        // -- Act --
        sut.distribution(key: "test", value: 1.0, unit: nil, attributes: [:])

        // -- Assert --
        XCTAssertNil(mock.distributionInvocations.first?["unit"])
    }

    func testGaugeWithNilUnit_shouldForwardNil() {
        // -- Act --
        sut.gauge(key: "test", value: 1.0, unit: nil, attributes: [:])

        // -- Assert --
        XCTAssertNil(mock.gaugeInvocations.first?["unit"])
    }
    #endif // !SDK_V10
}
