@testable import Sentry
import XCTest

class SentryInternalAppStartApiTests: XCTestCase {

    private let sut = SentryInternalAppStartApi()

    override func tearDown() {
        sut.hybridSDKMode = false
        super.tearDown()
    }

    // MARK: - hybridSDKMode

    func testHybridSDKMode_defaultIsFalse() {
        XCTAssertFalse(sut.hybridSDKMode)
    }

    func testHybridSDKMode_whenSet_shouldUpdateValue() {
        sut.hybridSDKMode = true
        XCTAssertTrue(sut.hybridSDKMode)
    }

    // MARK: - measurementWithSpans

    func testMeasurementWithSpans_beforeStart_shouldReturnNil() {
        XCTAssertNil(sut.measurementWithSpans)
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testMeasurementWithSpans_withPreWarmedMeasurement_shouldSerializeSpansAndNSNumberValues() throws {
        // -- Arrange --
        let measurement = TestData.getAppStartMeasurement(
            type: .warm,
            appStartTimestamp: Date(timeIntervalSince1970: 5),
            runtimeInitSystemTimestamp: 1,
            preWarmed: true,
            moduleInitializationTimestamp: Date(timeIntervalSince1970: 20),
            runtimeInitTimestamp: Date(timeIntervalSince1970: 15),
            sdkStartTimestamp: Date(timeIntervalSince1970: 10)
        )
        SentrySDKInternal.setAppStartMeasurement(measurement)
        defer { SentrySDKInternal.setAppStartMeasurement(nil) }

        // -- Act --
        let result = try XCTUnwrap(sut.measurementWithSpans)

        // -- Assert --
        XCTAssertEqual(result["type"] as? String, "warm")
        XCTAssertEqual(result["is_pre_warmed"] as? Int, 1)
        XCTAssertEqual(result["app_start_timestamp_ms"] as? Int, 5_000)
        XCTAssertEqual(result["runtime_init_timestamp_ms"] as? Int, 15_000)
        XCTAssertEqual(result["module_initialization_timestamp_ms"] as? Int, 20_000)
        XCTAssertEqual(result["sdk_start_timestamp_ms"] as? Int, 10_000)

        let spans = try XCTUnwrap(result["spans"] as? [[String: Any]])
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(spans.element(at: 0)?["description"] as? String, "Pre Runtime Init")
        XCTAssertEqual(spans.element(at: 1)?["description"] as? String, "Runtime init to Pre Main initializers")
        XCTAssertEqual(spans.element(at: 2)?["description"] as? String, "UIKit init")
    }
#endif
}
