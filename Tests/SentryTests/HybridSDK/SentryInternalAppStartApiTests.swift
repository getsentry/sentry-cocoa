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
}
