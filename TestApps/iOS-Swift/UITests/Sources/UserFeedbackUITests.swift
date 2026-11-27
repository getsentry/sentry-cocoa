// swiftlint:disable file_length

import SentrySampleShared
import XCTest

class UserFeedbackUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    let fm = FileManager.default
    
    /// The Application Support directory is different between this UITest runner app and the target app under test. We have to retrieve the target app's app support directory using UI elements and store it here for usage.
    /// - note: The SDK does not use application support for anything. We only use the app support directory for these tests to write marker files from the app indicating which feedback hooks have fired.
    var appSupportDirectory: String?
    
    override func setUp() {
        super.setUp()
        
        app.launchArguments.append(contentsOf: [
            SentrySDKOverrides.Feedback.noAnimations.rawValue,
            SentrySDKOverrides.Special.wipeDataOnLaunch.rawValue,
            
            // since the goal of these tests is only to exercise the UI of the widget and form, disable other SDK features to avoid any confounding factors that might fail or crash a test case
            SentrySDKOverrides.Special.disableEverything.rawValue,
            
            // write base64-encoded data into the envelope file for attachments instead of raw bytes, specifically for images. this way the entire envelope contents can be more easily passed as a string through the text field in the app to this process for validation.
            SentrySDKOverrides.Attachments.base64Data.rawValue
        ])
        continueAfterFailure = true
    }
}

extension UserFeedbackUITests {
    func testSimulateScreenshot_whenTapped_shouldPresentFeedbackWithScreenshot() {
        // -- Arrange --
        launchApp(env: [
            SentrySDKOverrides.Special.dsn.rawValue: "http://public@127.0.0.1:9/1"
        ], activateBeforeLaunch: false)
        defer { app.terminate() }
        app.buttons["More"].tap()
        app.tables.staticTexts["Feedback"].tap()
        let simulateScreenshotButton = app.buttons["Simulate Screenshot"]
        XCTAssertTrue(simulateScreenshotButton.waitForExistence(timeout: 5))

        // -- Act --
        simulateScreenshotButton.tap()

        // -- Assert --
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        XCTAssertTrue(messageTextView.exists)
        XCTAssertTrue(removeScreenshotButton.exists)
    }

    // MARK: Tests validating screenshot functionality
    
    func testAddingScreenshots() throws {
        launchApp(args: [
            SentrySDKOverrides.Feedback.injectScreenshot.rawValue
        ])
        XCTAssertTrue(removeScreenshotButton.isHittable)
        
        let testMessage = "UITest user feedback"
        fillInFields(testMessage)
        
        submit(waitingForWidget: false)
        
        try assertEnvelopeContents(testMessage, attachments: true)
    }
    
    func testAddingAndRemovingScreenshots() throws {
        launchApp(args: [
            SentrySDKOverrides.Feedback.injectScreenshot.rawValue
        ])
        XCTAssertTrue(removeScreenshotButton.isHittable)
        removeScreenshotButton.tap()
        XCTAssertFalse(removeScreenshotButton.isHittable)
        
        let testMessage = "UITest user feedback"
        fillInFields(testMessage)
        
        submit(waitingForWidget: false)
        
        try assertEnvelopeContents(testMessage)
    }
    
}

// MARK: UI Element access
extension UserFeedbackUITests {
    var cancelButton: XCUIElement {
        app.buttons["io.sentry.feedback.form.cancel"]
    }
    
    var sendButton: XCUIElement {
        app.buttons["io.sentry.feedback.form.submit"]
    }
    
    var widgetButton: XCUIElement {
        app.otherElements["io.sentry.feedback.widget"]
    }
    
    var customButton: XCUIElement {
        app.buttons["io.sentry.feedback.custom-button"]
    }

    var nameField: XCUIElement {
        app.textFields["io.sentry.feedback.form.name"]
    }
    
    var emailField: XCUIElement {
        app.textFields["io.sentry.feedback.form.email"]
    }
    
    var messageTextView: XCUIElement {
        app.textViews["io.sentry.feedback.form.message"]
    }
    
    var removeScreenshotButton: XCUIElement {
        app.buttons["io.sentry.feedback.form.remove-screenshot"]
    }
    
    var extrasAreaTabBarButton: XCUIElement {
        app.buttons["Extra"]
    }
    
    var errorsAreaTabBarButton: XCUIElement {
        app.buttons["Errors"]
    }
    
    var dataMarshalingField: XCUIElement {
        app.textFields["io.sentry.ui-test.text-field.data-marshaling.extras"]
    }
}

// MARK: Form hook test helpers
extension UserFeedbackUITests {
    func submit(expectingError: Bool = false, usingCustomButton: Bool = false, waitingForWidget: Bool = true) {
        sendButton.tap()
        if !expectingError {
            if usingCustomButton {
                customButton.waitForExistence("Form should have been dismissed and custom button should be visible again.")
            } else if waitingForWidget {
                widgetButton.waitForExistence("Form should have been dismissed and widget button should be visible again.")
            } else {
                XCTAssertFalse(sendButton.waitForExistence(timeout: 1))
            }
        }
    }
    
    func path(for marker: HookMarkerFile) throws -> String {
        let appSupportDirectory = try XCTUnwrap(appSupportDirectory)
        return "\(appSupportDirectory)/io.sentry/feedback/\(marker.rawValue)"
    }
    
    func assertFormHookFile(type: HookMarkerFile, exists: Bool) throws {
        let path = try path(for: type)
        if exists {
            XCTAssertTrue(fm.fileExists(atPath: path), "Expected file to exist at \(path)")
        } else {
            XCTAssertFalse(fm.fileExists(atPath: path), "Expected file to not exist at \(path)")
        }
    }
    
    enum HookMarkerFile: String {
        case onFormOpen
        case onFormClose
        case onSubmitSuccess
        case onSubmitError
    }
    static let allHookMarkers: [HookMarkerFile] = [.onFormOpen, .onFormClose, .onSubmitSuccess, .onSubmitError]
    
    func assertOnlyHookMarkersExist(names: [HookMarkerFile]) throws {
        try names.forEach { try assertFormHookFile(type: $0, exists: true) }
        try Set(names).symmetricDifference(UserFeedbackUITests.allHookMarkers).forEach { try assertFormHookFile(type: $0, exists: false) }
    }
    
    func getMarkerFileContents(type: HookMarkerFile) throws -> String {
        let path = try path(for: type)
        return try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }
    
    func assertHookMarkersNotExist(names: [HookMarkerFile] = allHookMarkers) throws {
        try names.forEach { try assertFormHookFile(type: $0, exists: false) }
    }
    
    func retrieveAppUnderTestApplicationSupportDirectory() throws {
        guard appSupportDirectory == nil else { return }
        
        extrasAreaTabBarButton.tap()
        app.buttons["io.sentry.ui-test.button.get-application-support-directory"].tap()
        appSupportDirectory = try XCTUnwrap(dataMarshalingField.value as? String)
    }
    
    func fillInFields(_ testMessage: String, _ testName: String? = nil, _ testEmail: String? = nil) {
        if let testName = testName {
            nameField.tap()
            nameField.typeText(testName)
        }
        
        if let testEmail = testEmail {
            emailField.tap()
            emailField.typeText(testEmail)
        }
        
        messageTextView.tap()
        messageTextView.typeText(testMessage)
    }
    
    func assertEnvelopeContents(_ testMessage: String, _ testEmail: String? = nil, _ testName: String? = nil, attachments: Bool = false) throws {
        extrasAreaTabBarButton.tap()
        app.buttons["io.sentry.ui-test.button.get-latest-envelope"].tap()
        let marshaledDataBase64 = try XCTUnwrap(dataMarshalingField.value as? String)
        let data = try XCTUnwrap(Data(base64Encoded: marshaledDataBase64))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(dict["event_type"] as? String), "feedback")
        XCTAssertEqual(try XCTUnwrap(dict["message"] as? String), testMessage)
        if let testEmail = testEmail {
            XCTAssertEqual(try XCTUnwrap(dict["contact_email"] as? String), testEmail)
        }
        XCTAssertEqual(try XCTUnwrap(dict["source"] as? String), "widget")
        if let testName = testName {
            XCTAssertEqual(try XCTUnwrap(dict["name"] as? String), testName)
        }
        XCTAssertNotNil(dict["event_id"])
        XCTAssertEqual(try XCTUnwrap(dict["item_header_type"] as? String), "feedback")
        if attachments {
            XCTAssertNotNil(dict["feedback_attachments"])
            let screenshotDataStrings = try XCTUnwrap(dict["feedback_attachments"] as? [String])
            XCTAssertEqual(screenshotDataStrings.count, 1)
            let screenshotDataString = try XCTUnwrap(screenshotDataStrings.first)
            XCTAssertNotNil(UIImage(data: try XCTUnwrap(Data(base64Encoded: screenshotDataString))))
        }
    }
}

// swiftlint:enable file_length
