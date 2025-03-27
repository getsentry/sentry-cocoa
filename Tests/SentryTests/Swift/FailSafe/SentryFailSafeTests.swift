@testable import Sentry
import XCTest

final class SentryFailSafeTests: XCTestCase {

    func testAppVersionInitsFirstTime_NoSdkCrashDetected() {
        let detection = TestSentrySDKCrashDetection()

        let sut = SentryFailSafe(sdkCrashDetection: detection)
        defer { sut.reset() }

        sut.sdkStartStarted(releaseName: "1.0.0")

        XCTAssertFalse(detection.crashDetected)
    }

    func testSdkStartCompletesWithSuccess_NoSDKCrashDetected() {
        let detection1 = TestSentrySDKCrashDetection()
        let sut1 = SentryFailSafe(sdkCrashDetection: detection1)
        defer { sut1.reset() }

        sut1.sdkStartStarted(releaseName: "1.0.0")
        sut1.sdkStartFinished(releaseName: "1.0.0")

        let detection2 = TestSentrySDKCrashDetection()
        let sut2 = SentryFailSafe(sdkCrashDetection: detection2)
        defer { sut2.reset() }

        sut2.sdkStartStarted(releaseName: "1.0.0")

        XCTAssertFalse(detection1.crashDetected)
        XCTAssertFalse(detection2.crashDetected)
    }

    func testSdkStartDoesNotCompletesWithSuccess_SDKCrashDetected() {
        let detection1 = TestSentrySDKCrashDetection()
        let sut1 = SentryFailSafe(sdkCrashDetection: detection1)
        defer { sut1.reset() }

        sut1.sdkStartStarted(releaseName: "1.0.0")

        let detection2 = TestSentrySDKCrashDetection()
        let sut2 = SentryFailSafe(sdkCrashDetection: detection2)
        defer { sut2.reset() }

        sut2.sdkStartStarted(releaseName: "1.0.0")

        XCTAssertFalse(detection1.crashDetected)
        XCTAssertTrue(detection2.crashDetected)
    }

    func testSdkStartWithNewRelease_NoSDKCrashDetected() {
        let detection1 = TestSentrySDKCrashDetection()
        let sut1 = SentryFailSafe(sdkCrashDetection: detection1)
        defer { sut1.reset() }

        sut1.sdkStartStarted(releaseName: "1.0.0")

        let detection2 = TestSentrySDKCrashDetection()
        let sut2 = SentryFailSafe(sdkCrashDetection: detection2)
        defer { sut2.reset() }

        XCTAssertFalse(detection1.crashDetected)
        XCTAssertFalse(detection2.crashDetected)
    }
}

private class TestSentrySDKCrashDetection: SentrySDKCrashDetection {

    var crashDetected = false

    func sdkCrashDetected() {
        crashDetected = true
    }

}
