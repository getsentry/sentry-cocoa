import XCTest

class SessionReplayUITests: BaseUITest {

    func testCameraUI_shouldNotCrashOnIOS26() throws {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            throw XCTSkip("Camera UI is not available on this device.")
        }
        // -- Arrange --
        // During the beta phase of iOS 26.0 we noticed crashes when traversing the view hierarchy
        // of the camera UI. This test is used to verify that no regression occurs.
        // See https://github.com/getsentry/sentry-cocoa/issues/5647
        app.buttons["Extra"].tap()

        // -- Act --
        app.buttons["Show Camera UI"].tap()
        
        // We need to verify the camera UI is shown by checking for the existence of a UI element.
        // This can be any element that is part of the camera UI and can be found reliably.
        // The "PhotoCapture" button is a good candidate as it is always present when the
        // camera UI is shown.
        let cameraUIElement = app.buttons["PhotoCapture"]
        XCTAssertTrue(cameraUIElement.waitForExistence(timeout: 5))

        // After the Camera UI is shown, we keep it open for 10 seconds to trigger at least one full
        // video segment captured (segments are 5 seconds long).
        delay(seconds: 10)

        // -- Assert --
        // We know the test succeeded if we reach this point without the app crashing.
        XCTAssertTrue(cameraUIElement.waitForExistence(timeout: 5))
    }
}
