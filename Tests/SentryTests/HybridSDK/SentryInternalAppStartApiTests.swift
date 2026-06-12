@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryInternalAppStartApiTests: XCTestCase {

    private var sut: SentryInternalAppStartApi { SentrySDK.internal.appStart }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - hybridSDKMode

    func testHybridSDKMode_whenDefault_shouldBeFalse() {
        // -- Act --
        let result = sut.hybridSDKMode

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testHybridSDKMode_whenSetToTrue_shouldPersist() {
        // -- Act --
        sut.hybridSDKMode = true

        // -- Assert --
        XCTAssertTrue(sut.hybridSDKMode)
    }

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

    // MARK: - measurement

    func testMeasurement_whenSet_shouldReturnValue() {
        // -- Arrange --
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm, runtimeInitSystemTimestamp: 1)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        // -- Act --
        let result = sut.measurement

        // -- Assert --
        XCTAssertEqual(result, appStartMeasurement)
    }

    func testMeasurement_whenNil_shouldReturnNil() {
        // -- Arrange --
        SentrySDKInternal.setAppStartMeasurement(nil)

        // -- Act --
        let result = sut.measurement

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - measurementWithSpans

    func testMeasurementWithSpans_whenCold_shouldIncludeType() throws {
        // -- Arrange --
        SentrySDKInternal.setAppStartMeasurement(
            TestData.getAppStartMeasurement(type: .cold, runtimeInitSystemTimestamp: 1)
        )

        // -- Act --
        let result = try XCTUnwrap(sut.measurementWithSpans)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(result["type"] as? String), "cold")
        let spans = try XCTUnwrap(result["spans"] as? NSArray)
        XCTAssertGreaterThan(spans.count, 0)
    }

    func testMeasurementWithSpans_whenWarmPreWarmed_shouldIncludeMultipleSpans() throws {
        // -- Arrange --
        SentrySDKInternal.setAppStartMeasurement(
            TestData.getAppStartMeasurement(
                type: .warm,
                runtimeInitSystemTimestamp: 1,
                preWarmed: true
            )
        )

        // -- Act --
        let result = try XCTUnwrap(sut.measurementWithSpans)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(result["type"] as? String), "warm")
        XCTAssertEqual(try XCTUnwrap(result["is_pre_warmed"] as? Int), 1)
        let spans = try XCTUnwrap(result["spans"] as? [NSDictionary])
        XCTAssertEqual(spans.count, 3)
    }

    // MARK: - onMeasurementAvailable

    func testOnMeasurementAvailable_whenDefault_shouldBeNil() {
        // -- Act --
        let result = sut.onMeasurementAvailable

        // -- Assert --
        XCTAssertNil(result)
    }

    func testOnMeasurementAvailable_whenSet_shouldPersist() {
        // -- Arrange --
        var callbackInvoked = false

        // -- Act --
        sut.onMeasurementAvailable = { _ in callbackInvoked = true }

        // -- Assert --
        XCTAssertNotNil(sut.onMeasurementAvailable)
        sut.onMeasurementAvailable?(nil)
        XCTAssertTrue(callbackInvoked)
    }

    #endif
}
