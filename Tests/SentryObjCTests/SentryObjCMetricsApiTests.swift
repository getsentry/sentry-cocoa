import SentryObjC
import SentryTestUtils
import XCTest

final class SentryObjCMetricsApiTests: XCTestCase {

    private var mock = TestMetricsApi()
    private var sut = SentryObjCMetricsApi(testApi: TestMetricsApi())

    override func setUp() {
        super.setUp()
        mock = TestMetricsApi()
        sut = SentryObjCMetricsApi(testApi: mock)
    }

    // MARK: - count

    func testCountWithKeyValueAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.count(withKey: "events", value: 5, attributes: ["source": .string("test")])

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?["key"] as? String, "events")
        XCTAssertEqual(mock.countInvocations.first?["value"] as? UInt, 5)
    }

    func testCountWithKeyValue_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.count(withKey: "events", value: 3)

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?["key"] as? String, "events")
        XCTAssertEqual(mock.countInvocations.first?["value"] as? UInt, 3)
    }

    func testCountWithKey_shouldForwardWithValueOneAndEmptyAttributes() {
        // -- Act --
        sut.count(withKey: "events")

        // -- Assert --
        XCTAssertEqual(mock.countInvocations.count, 1)
        XCTAssertEqual(mock.countInvocations.first?["key"] as? String, "events")
        XCTAssertEqual(mock.countInvocations.first?["value"] as? UInt, 1)
    }

    // MARK: - distribution

    func testDistributionWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.distribution(
            withKey: "latency",
            value: 42.5,
            unit: .millisecond,
            attributes: ["endpoint": .string("/api")]
        )

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?["key"] as? String, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?["value"] as? Double, 42.5)
        XCTAssertEqual(mock.distributionInvocations.first?["unit"] as? String, "millisecond")
    }

    func testDistributionWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.distribution(withKey: "latency", value: 10.0, unit: .second)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?["key"] as? String, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?["value"] as? Double, 10.0)
        XCTAssertEqual(mock.distributionInvocations.first?["unit"] as? String, "second")
    }

    func testDistributionWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.distribution(withKey: "latency", value: 5.0)

        // -- Assert --
        XCTAssertEqual(mock.distributionInvocations.count, 1)
        XCTAssertEqual(mock.distributionInvocations.first?["key"] as? String, "latency")
        XCTAssertEqual(mock.distributionInvocations.first?["value"] as? Double, 5.0)
        XCTAssertNil(mock.distributionInvocations.first?["unit"])
    }

    // MARK: - gauge

    func testGaugeWithKeyValueUnitAttributes_shouldForwardAllParameters() {
        // -- Act --
        sut.gauge(
            withKey: "memory",
            value: 1_024.0,
            unit: .byte,
            attributes: ["process": .string("main")]
        )

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?["key"] as? String, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?["value"] as? Double, 1_024.0)
        XCTAssertEqual(mock.gaugeInvocations.first?["unit"] as? String, "byte")
    }

    func testGaugeWithKeyValueUnit_shouldForwardWithEmptyAttributes() {
        // -- Act --
        sut.gauge(withKey: "memory", value: 512.0, unit: .megabyte)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?["key"] as? String, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?["value"] as? Double, 512.0)
        XCTAssertEqual(mock.gaugeInvocations.first?["unit"] as? String, "megabyte")
    }

    func testGaugeWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes() {
        // -- Act --
        sut.gauge(withKey: "memory", value: 256.0)

        // -- Assert --
        XCTAssertEqual(mock.gaugeInvocations.count, 1)
        XCTAssertEqual(mock.gaugeInvocations.first?["key"] as? String, "memory")
        XCTAssertEqual(mock.gaugeInvocations.first?["value"] as? Double, 256.0)
        XCTAssertNil(mock.gaugeInvocations.first?["unit"])
    }
}
