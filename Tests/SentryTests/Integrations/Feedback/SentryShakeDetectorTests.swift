@testable import Sentry
import XCTest

#if os(iOS)
import UIKit

final class SentryShakeDetectorTests: XCTestCase {

    private static let mockWindowScene: UIWindowScene = MockUIWindowScene()

    private func makeWindow() -> UIWindow {
        UIWindow(windowScene: Self.mockWindowScene)
    }

    override func tearDown() {
        super.tearDown()
        SentryShakeDetector.disable()
    }

    func testEnable_whenShakeOccurs_shouldPostNotification() {
        let expectation = expectation(forNotification: .SentryShakeDetected, object: nil)

        SentryShakeDetector.enable()

        let window = makeWindow()
        window.motionEnded(.motionShake, with: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testDisable_whenShakeOccurs_shouldNotPostNotification() {
        SentryShakeDetector.enable()
        SentryShakeDetector.disable()

        let expectation = expectation(forNotification: .SentryShakeDetected, object: nil)
        expectation.isInverted = true

        let window = makeWindow()
        window.motionEnded(.motionShake, with: nil)

        wait(for: [expectation], timeout: 0.5)
    }

    func testEnable_whenNonShakeMotion_shouldNotPostNotification() {
        SentryShakeDetector.enable()

        let expectation = expectation(forNotification: .SentryShakeDetected, object: nil)
        expectation.isInverted = true

        let window = makeWindow()
        window.motionEnded(.none, with: nil)

        wait(for: [expectation], timeout: 0.5)
    }

    func testEnable_calledMultipleTimes_shouldNotCrash() {
        SentryShakeDetector.enable()
        SentryShakeDetector.enable()
        SentryShakeDetector.enable()

        let window = makeWindow()
        window.motionEnded(.motionShake, with: nil)
    }

    func testDisable_withoutEnable_shouldNotCrash() {
        SentryShakeDetector.disable()
    }

    func testCooldown_whenShakesTooFast_shouldPostOnlyOnce() {
        SentryShakeDetector.enable()

        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .SentryShakeDetected, object: nil, queue: nil
        ) { _ in
            notificationCount += 1
        }

        let window = makeWindow()
        // Rapid shakes within the 1s cooldown
        window.motionEnded(.motionShake, with: nil)
        window.motionEnded(.motionShake, with: nil)
        window.motionEnded(.motionShake, with: nil)

        XCTAssertEqual(notificationCount, 1)

        NotificationCenter.default.removeObserver(observer)
    }

    func testOriginalImplementation_shouldStillBeCalled() {
        SentryShakeDetector.enable()

        let window = makeWindow()
        window.motionEnded(.motionShake, with: nil)
        window.motionEnded(.remoteControlBeginSeekingBackward, with: nil)
    }
}

#endif
