import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import SentryTestUtils
import XCTest

private struct CountInvocation: Equatable {
    let key: String
    let value: UInt
    let attributes: [String: SentryAttributeValue]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value && lhs.attributes.keys == rhs.attributes.keys
    }
}

private struct DistributionInvocation {
    let key: String
    let value: Double
    let unit: SentryUnit?
    let attributes: [String: SentryAttributeValue]
}

private struct GaugeInvocation {
    let key: String
    let value: Double
    let unit: SentryUnit?
    let attributes: [String: SentryAttributeValue]
}

private final class MockMetricsApi: SentryMetricsApiProtocol {
    let countInvocations = Invocations<CountInvocation>()
    let distributionInvocations = Invocations<DistributionInvocation>()
    let gaugeInvocations = Invocations<GaugeInvocation>()

    func count(key: String, value: UInt, attributes: [String: SentryAttributeValue]) {
        countInvocations.record(CountInvocation(key: key, value: value, attributes: attributes))
    }

    func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        distributionInvocations.record(DistributionInvocation(key: key, value: value, unit: unit, attributes: attributes))
    }

    func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        gaugeInvocations.record(GaugeInvocation(key: key, value: value, unit: unit, attributes: attributes))
    }
}

final class SentryObjCCompatMetricsApiTests: XCTestCase {

    private var mock = MockMetricsApi()
    private var sut = SentryObjCMetricsApi(MockMetricsApi())

    override func setUp() {
        super.setUp()
        mock = MockMetricsApi()
        sut = SentryObjCMetricsApi(mock)
    }

    // MARK: - count

    func testCountWithKeyValueAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.count(key: "events", value: 5, attributes: ["source": .string("test")])

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        let inv = mock.countInvocations.first
        XCTAssertEqual(inv?.key, "events")
        XCTAssertEqual(inv?.value, 5)
        XCTAssertEqual(inv?.attributes.count, 1)
    }

    func testCountWithKeyValue_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.count(key: "events", value: 3)

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?.key, "events")
        XCTAssertEqual(mock.countInvocations.first?.value, 3)
        XCTAssertEqual(mock.countInvocations.first?.attributes.count, 0)
    }

    func testCountWithKey_shouldForwardWithValueOneAndEmptyAttributes() {
        // -- Act --
        sut.count(key: "events")

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?.key, "events")
        XCTAssertEqual(mock.countInvocations.first?.value, 1)
        XCTAssertEqual(mock.countInvocations.first?.attributes.count, 0)
    }

    // MARK: - distribution

    func testDistributionWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.distribution(key: "latency", value: 42.5, unit: .millisecond, attributes: ["endpoint": .string("/api")])

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        let inv = mock.distributionInvocations.first
        XCTAssertEqual(inv?.key, "latency")
        XCTAssertEqual(inv?.value, 42.5)
        XCTAssertNotNil(inv?.unit)
        XCTAssertEqual(inv?.attributes.count, 1)
    }

    func testDistributionWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.distribution(key: "latency", value: 10.0, unit: .second)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?.key, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?.value, 10.0)
        XCTAssertNotNil(mock.distributionInvocations.first?.unit)
        XCTAssertEqual(mock.distributionInvocations.first?.attributes.count, 0)
    }

    func testDistributionWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.distribution(key: "latency", value: 5.0)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?.key, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?.value, 5.0)
        XCTAssertNil(mock.distributionInvocations.first?.unit)
        XCTAssertEqual(mock.distributionInvocations.first?.attributes.count, 0)
    }

    // MARK: - gauge

    func testGaugeWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.gauge(key: "memory", value: 1_024.0, unit: .byte, attributes: ["process": .string("main")])

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        let inv = mock.gaugeInvocations.first
        XCTAssertEqual(inv?.key, "memory")
        XCTAssertEqual(inv?.value, 1_024.0)
        XCTAssertNotNil(inv?.unit)
        XCTAssertEqual(inv?.attributes.count, 1)
    }

    func testGaugeWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.gauge(key: "memory", value: 512.0, unit: .megabyte)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?.key, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?.value, 512.0)
        XCTAssertNotNil(mock.gaugeInvocations.first?.unit)
        XCTAssertEqual(mock.gaugeInvocations.first?.attributes.count, 0)
    }

    func testGaugeWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.gauge(key: "memory", value: 256.0)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?.key, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?.value, 256.0)
        XCTAssertNil(mock.gaugeInvocations.first?.unit)
        XCTAssertEqual(mock.gaugeInvocations.first?.attributes.count, 0)
    }

    // MARK: - nil unit

    func testDistributionWithNilUnit_shouldForwardNil() {
        // -- Act --
        sut.distribution(key: "test", value: 1.0, unit: nil, attributes: [:])

        // -- Assert --
        XCTAssertNil(mock.distributionInvocations.first?.unit)
    }

    func testGaugeWithNilUnit_shouldForwardNil() {
        // -- Act --
        sut.gauge(key: "test", value: 1.0, unit: nil, attributes: [:])

        // -- Assert --
        XCTAssertNil(mock.gaugeInvocations.first?.unit)
    }
}
