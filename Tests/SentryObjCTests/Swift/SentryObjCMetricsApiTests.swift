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
        XCTAssertNotNil(inv["scope"])
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
        XCTAssertNotNil(inv["scope"])
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
        XCTAssertNotNil(inv["scope"])
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

}
