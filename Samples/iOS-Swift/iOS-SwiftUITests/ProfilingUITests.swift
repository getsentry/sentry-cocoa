import XCTest

final class ProfilingUITests: XCTestCase {
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["io.sentry.ui-test.test-name"] = name
        app.launch()
    }

    /**
     * We had a bug where we forgot to install the frames tracker into the profiler, so weren't sending any GPU frame information with profiles. Since it's not possible to enforce such installation via the compiler, we test for the results we expect here, by starting a transaction, triggering an ANR which will cause degraded frame rendering, stop the transaction, and inspect the profile payload.
     */
    func testProfilingGPUInfo() throws {
        // We don't need to test this on multiple OSes right now, and older versions seem to have issues; older devices or VM images running simulators might just be slower. Latest OS is enough coverage for our needs for now.
        guard #available(iOS 15.0, *) else {
           throw XCTSkip("Only run on iOS 15 and above.")
        }

        XCUIApplication().tabBars["Tab Bar"].buttons["Transactions"].tap()
        app.buttons["Start transaction"].afterWaitingForExistence("Couldn't find button to start transaction").tap()
        XCUIApplication().tabBars["Tab Bar"].buttons["Extra"].tap()
        app.buttons["ANR filling run loop"].afterWaitingForExistence("Couldn't find button to ANR").tap()
        XCUIApplication().tabBars["Tab Bar"].buttons["Transactions"].tap()
        app.buttons["Stop transaction"].afterWaitingForExistence("Couldn't find button to end transaction").tap()

        XCUIApplication().tabBars["Tab Bar"].buttons["Extra"].tap()
        let textField = app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"]
        textField.waitForExistence("Couldn't find profile marshaling text field.")

        let profileBase64DataString = try XCTUnwrap(textField.value as? NSString)
        let profileData = try XCTUnwrap(Data(base64Encoded: profileBase64DataString as String))
        let profileDict = try XCTUnwrap(try JSONSerialization.jsonObject(with: profileData) as? [String: Any])

        let metrics = try XCTUnwrap(profileDict["measurements"] as? [String: Any])
        let slowFrames = try XCTUnwrap(metrics["slow_frame_renders"] as? [String: Any])
        let slowFrameValues = try XCTUnwrap(slowFrames["values"] as? [[String: Any]])
        let frozenFrames = try XCTUnwrap(metrics["frozen_frame_renders"] as? [String: Any])
        let frozenFrameValues = try XCTUnwrap(frozenFrames["values"] as? [[String: Any]])
        XCTAssertFalse(slowFrameValues.isEmpty && frozenFrameValues.isEmpty)

        let frameRates = try XCTUnwrap(metrics["screen_frame_rates"] as? [String: Any])
        let frameRateValues = try XCTUnwrap(frameRates["values"] as? [[String: Any]])
        XCTAssertFalse(frameRateValues.isEmpty)
    }
}
