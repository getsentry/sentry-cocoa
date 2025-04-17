//swiftlint:disable file_length

import XCTest

class UserFeedbackUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    let fm = FileManager.default
    
    /// The Application Support directory is different between this UITest runner app and the target app under test. We have to retrieve the target app's app support directory using UI elements and store it here for usage.
    var appSupportDirectory: String?
    
    override func setUp() {
        super.setUp()
        
        app.launchArguments.append(contentsOf: [
            "--io.sentry.feedback.no-animations",
            "--io.sentry.wipe-data",
            
            // since the goal of these tests is only to exercise the UI of the widget and form, disable other SDK features to avoid any confounding factors that might fail or crash a test case
            "--io.sentry.disable-everything",
            
            // write base64-encoded data into the envelope file for attachments instead of raw bytes, specifically for images. this way the entire envelope contents can be more easily passed as a string through the text field in the app to this process for validation.
            "--io.sentry.base64-attachment-data"
        ])
        continueAfterFailure = true
    }
}

extension UserFeedbackUITests {
    // MARK: Tests ensuring correct appearance
    
    func testUIElementsWithDefaults() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        // widget button text
        XCTAssert(app.otherElements["Report a Bug"].exists)
        
        widgetButton.tap()
        
        // Form title
        XCTAssert(app.staticTexts["Report a Bug"].exists)
        
        // form buttons
        XCTAssert(app.staticTexts["Cancel"].exists)
        XCTAssert(app.staticTexts["Send Bug Report"].exists)
                
        // Input field placeholders
        XCTAssertEqual(try XCTUnwrap(nameField.placeholderValue), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.placeholderValue), "your.email@example.org")
        XCTAssert(app.staticTexts["What's the bug? What did you expect?"].exists)
        
        // Input field labels
        XCTAssert(app.staticTexts["Email"].exists)
        XCTAssert(app.staticTexts["Name"].exists)
        XCTAssert(app.staticTexts["Description (Required)"].exists)
        XCTAssertFalse(app.staticTexts["Email (Required)"].exists)
        XCTAssertFalse(app.staticTexts["Name (Required)"].exists)
    }
    
    func testUIElementsWithCustomizations() {
        launchApp()
        
        // widget button text
        XCTAssert(app.otherElements["Report Jank"].exists)
        
        widgetButton.tap()
        
        // Form title
        XCTAssert(app.staticTexts["Jank Report"].exists)
        
        // form buttons
        XCTAssert(app.staticTexts["Report that jank"].exists)
        XCTAssert(app.staticTexts["What, me worry?"].exists)
                
        // Input field placeholders
        XCTAssertEqual(try XCTUnwrap(nameField.placeholderValue), "Yo name")
        XCTAssertEqual(try XCTUnwrap(emailField.placeholderValue), "Yo email")
        XCTAssert(app.staticTexts["Describe the nature of the jank. Its essence, if you will."].exists)
        
        // Input field labels
        XCTAssert(app.staticTexts["Thine email"].exists)
        XCTAssert(app.staticTexts["Thy name"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        XCTAssertFalse(app.staticTexts["Thine email (Required)"].exists)
        XCTAssertFalse(app.staticTexts["Thy name (Required)"].exists)
    }
    
    func testPrefilledUserInformation() throws {
        launchApp(args: [
            "--io.sentry.feedback.all-defaults"
        ], env: [
            "--io.sentry.user.name": "ui test user",
            "--io.sentry.user.email": "ui-testing@sentry.io"
        ])
        
        widgetButton.tap()
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "ui test user")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "ui-testing@sentry.io")
    }
    
    func testNoPrefilledUserInformation() throws {
        launchApp(args: [
            "--io.sentry.feedback.dont-use-sentry-user"
        ], env: [
            "--io.sentry.user.name": "ui test user",
            "--io.sentry.user.email": "ui-testing@sentry.io"
        ])
        
        widgetButton.tap()
        
        // XCUIElement.value returns the placeholder value when empty, which they should be here
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Yo name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "Yo email")
    }
    
    // MARK: Tests validating happy path / successful submission
    
    func testSubmitFullyFilledCustomForm() throws {
        launchApp(args: ["--io.sentry.feedback.dont-use-sentry-user"])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        XCTAssert(nameField.waitForExistence(timeout: 1))
        try assertOnlyHookMarkersExist(names: [.onFormOpen])
        
        let testName = "Andrew"
        let testEmail = "custom@email.com"
        let testMessage = "UITest user feedback"

        fillInFields(testMessage, testName, testEmail)
        
        submit()
        
        try assertOnlyHookMarkersExist(names: [.onFormClose, .onSubmitSuccess])
        XCTAssertEqual(try dictionaryFromSuccessHookFile(), ["message": "UITest user feedback", "email": testEmail, "name": testName])
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        // these will be prefilled by default
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Yo name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "Yo email")
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
        
        cancelButton.tap()
        
        try assertEnvelopeContents(testMessage, testEmail, testName)
    }
    
    func testSubmitFullyFilledForm() throws {
        let testName = "Andrew"
        let testContactEmail = "andrew.mcknight@sentry.io"
        
        launchApp(args: ["--io.sentry.feedback.all-defaults"], env: [
            "--io.sentry.user.name": testName,
            "--io.sentry.user.email": testContactEmail
        ])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        XCTAssert(nameField.waitForExistence(timeout: 1))
        try assertOnlyHookMarkersExist(names: [.onFormOpen])
        
        let testMessage = "UITest user feedback"
        fillInFields(testMessage)
        
        submit()
        
        try assertOnlyHookMarkersExist(names: [.onFormClose, .onSubmitSuccess])
        XCTAssertEqual(try dictionaryFromSuccessHookFile(), ["message": "UITest user feedback", "email": testContactEmail, "name": testName])
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        // these will be prefilled by default
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), testName)
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), testContactEmail)
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
        
        cancelButton.tap()
        
        extrasAreaTabBarButton.tap()
        app.buttons["io.sentry.ui-test.button.get-latest-envelope"].tap()
        let marshaledDataBase64 = try XCTUnwrap(dataMarshalingField.value as? String)
        let data = try XCTUnwrap(Data(base64Encoded: marshaledDataBase64))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(dict["event_type"] as? String), "feedback")
        XCTAssertEqual(try XCTUnwrap(dict["message"] as? String), testMessage)
        XCTAssertEqual(try XCTUnwrap(dict["contact_email"] as? String), testContactEmail)
        XCTAssertEqual(try XCTUnwrap(dict["source"] as? String), "widget")
        XCTAssertEqual(try XCTUnwrap(dict["name"] as? String), testName)
        XCTAssertNotNil(dict["event_id"])
        XCTAssertEqual(try XCTUnwrap(dict["item_header_type"] as? String), "feedback")
    }
    
    func dictionaryFromSuccessHookFile() throws -> [String: String] {
        let actual = try getMarkerFileContents(type: .onSubmitSuccess)
        let data = try XCTUnwrap(Data(base64Encoded: actual))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
    }
    
    func base64Representation(of dict: [String: Any]) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .sortedKeys)
        return jsonData.base64EncodedString()
    }
    
    func testSubmitWithOnlyRequiredFieldsFilled() throws {
        let testName = "Andrew"
        let testContactEmail = "andrew.mcknight@sentry.io"
        
        launchApp(args: ["--io.sentry.feedback.all-defaults"], env: [
            "--io.sentry.user.name": testName,
            "--io.sentry.user.email": testContactEmail
        ])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        XCTAssert(sendButton.waitForExistence(timeout: 1))
        try assertOnlyHookMarkersExist(names: [.onFormOpen])
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        submit()
        
        try assertOnlyHookMarkersExist(names: [.onFormClose, .onSubmitSuccess])
        XCTAssertEqual(try dictionaryFromSuccessHookFile(), ["name": testName, "message": "UITest user feedback", "email": testContactEmail])
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
    }
    
    // MARK: Tests validating cancellation functions correctly
    
    func testCancelFromFormByButton() throws {
        let testName = "Andrew"
        let testContactEmail = "andrew.mcknight@sentry.io"
        
        launchApp(args: ["--io.sentry.feedback.all-defaults"], env: [
            "--io.sentry.user.name": testName,
            "--io.sentry.user.email": testContactEmail
        ])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        XCTAssert(sendButton.waitForExistence(timeout: 1))
        try assertOnlyHookMarkersExist(names: [.onFormOpen])
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        let cancelButton: XCUIElement = app.staticTexts["Cancel"]
        cancelButton.tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormClose])
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), testName)
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), testContactEmail)
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
    }
    
    func testCancelFromFormBySwipeDown() throws {
        if UIDevice.current.userInterfaceIdiom == .pad {
            throw XCTSkip("Swipe down to cancel not applicable on iPad")
        }
        
        let testName = "Andrew"
        let testContactEmail = "andrew.mcknight@sentry.io"
        
        launchApp(args: ["--io.sentry.feedback.all-defaults"], env: [
            "--io.sentry.user.name": testName,
            "--io.sentry.user.email": testContactEmail
        ])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        XCTAssert(sendButton.waitForExistence(timeout: 1))
        try assertOnlyHookMarkersExist(names: [.onFormOpen])

        // the modal cancel gesture
        app.swipeDown(velocity: .fast)
        
        // the swipe dismiss animation takes an extra moment, so we need to wait for the widget to be visible again
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
        
        try assertOnlyHookMarkersExist(names: [.onFormClose])
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), testName)
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), testContactEmail)

        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
    }
    
    // MARK: Tests validating screenshot functionality
    
    func testAddingScreenshots() throws {
        launchApp(args: ["--io.sentry.feedback.inject-screenshot"])
        XCTAssert(removeScreenshotButton.isHittable)
        
        let testMessage = "UITest user feedback"
        fillInFields(testMessage)
        
        submit()
        
        try assertEnvelopeContents(testMessage, attachments: true)
    }
    
    func testAddingAndRemovingScreenshots() throws {
        launchApp(args: ["--io.sentry.feedback.inject-screenshot"])
        XCTAssert(removeScreenshotButton.isHittable)
        removeScreenshotButton.tap()
        XCTAssertFalse(removeScreenshotButton.isHittable)
        
        let testMessage = "UITest user feedback"
        fillInFields(testMessage)
        
        submit()
        
        try assertEnvelopeContents(testMessage)
    }
    
    // MARK: Tests validating error cases
    
    func testSubmitWithNoFieldsFilledDefault() throws {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        
        submit(expectingError: true)
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information before submitting. Please check the following field: description."].exists)
        
        app.buttons["OK"].tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormOpen, .onSubmitError])
        
        XCTAssertEqual(try getMarkerFileContents(type: .onSubmitError), "io.sentry.error;1;The user did not complete the feedback form.;description")
    }
    
    func testSubmitWithNoFieldsFilledEmailAndMessageRequired() throws {
        launchApp(args: ["--io.sentry.feedback.require-email", "--io.sentry.feedback.dont-use-sentry-user"])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        
        XCTAssert(app.staticTexts["Thine email (Required)"].exists)
        XCTAssert(app.staticTexts["Thy name"].exists)
        XCTAssertFalse(app.staticTexts["Thy name (Required)"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        
        submit(expectingError: true)
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information before submitting. Please check the following fields: thine email and thy complaint."].exists)
        
        app.buttons["OK"].tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormOpen, .onSubmitError])
        XCTAssertEqual(try getMarkerFileContents(type: .onSubmitError), "io.sentry.error;1;The user did not complete the feedback form.;thine email;thy complaint")
    }
    
    func testSubmitWithNoFieldsFilledAllRequired() throws {
        launchApp(args: [
            "--io.sentry.feedback.require-email",
            "--io.sentry.feedback.require-name",
            "--io.sentry.feedback.dont-use-sentry-user"
        ])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        
        XCTAssert(app.staticTexts["Thine email (Required)"].exists)
        XCTAssert(app.staticTexts["Thy name (Required)"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        
        submit(expectingError: true)
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts.element(matching: NSPredicate(format: "label LIKE 'You must provide all required information before submitting. Please check the following fields: thy name, thine email and thy complaint.'")).exists)
        
        app.buttons["OK"].tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormOpen, .onSubmitError])
        XCTAssertEqual(try getMarkerFileContents(type: .onSubmitError), "io.sentry.error;1;The user did not complete the feedback form.;thine email;thy complaint;thy name")
    }
    
    func testSubmitOnlyWithOptionalFieldsFilled() throws {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])

        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        
        submit(expectingError: true)
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information before submitting. Please check the following field: description."].exists)
        
        app.buttons["OK"].tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormOpen, .onSubmitError])
        XCTAssertEqual(try getMarkerFileContents(type: .onSubmitError), "io.sentry.error;1;The user did not complete the feedback form.;description")
    }
    
    func testSubmissionErrorThenSuccessAfterFixingIssues() throws {
        let testName = "Andrew"
        let testContactEmail = "andrew.mcknight@sentry.io"
        
        launchApp(args: ["--io.sentry.feedback.all-defaults"], env: [
            "--io.sentry.user.name": testName,
            "--io.sentry.user.email": testContactEmail
        ])
        
        try retrieveAppUnderTestApplicationSupportDirectory()
        try assertHookMarkersNotExist()
        
        widgetButton.tap()
        
        submit(expectingError: true)
        
        XCTAssert(app.staticTexts["Error"].exists)
        app.buttons["OK"].tap()
        
        try assertOnlyHookMarkersExist(names: [.onFormOpen, .onSubmitError])
        XCTAssertEqual(try getMarkerFileContents(type: .onSubmitError), "io.sentry.error;1;The user did not complete the feedback form.;description")
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        submit()
        
        try assertOnlyHookMarkersExist(names: [.onFormClose, .onSubmitSuccess])
        XCTAssertEqual(try dictionaryFromSuccessHookFile(), ["name": testName, "message": "UITest user feedback", "email": testContactEmail])
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
    
    var dataMarshalingField: XCUIElement {
        app.textFields["io.sentry.ui-test.text-field.data-marshaling.extras"]
    }
}

// MARK: Form hook test helpers
extension UserFeedbackUITests {
    func submit(expectingError: Bool = false) {
        sendButton.tap()
        if !expectingError {
            XCTAssert(widgetButton.waitForExistence(timeout: 1))
        }
    }
    
    func path(for marker: HookMarkerFile) throws -> String {
        let appSupportDirectory = try XCTUnwrap(appSupportDirectory)
        return "\(appSupportDirectory)/io.sentry/feedback/\(marker.rawValue)"
    }
    
    func assertFormHookFile(type: HookMarkerFile, exists: Bool) throws {
        let path = try path(for: type)
        if exists {
            XCTAssert(fm.fileExists(atPath: path), "Expected file to exist at \(path)")
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

//swiftlint:enable file_length
