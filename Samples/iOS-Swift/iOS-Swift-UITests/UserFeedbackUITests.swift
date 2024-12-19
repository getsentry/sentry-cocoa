//swiftlint:disable todo

import XCTest

class UserFeedbackUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    override func setUp() {
        super.setUp()
        
        app.launchArguments.append(contentsOf: [
            "--io.sentry.feedback.auto-inject-widget",
            "--io.sentry.feedback.no-animations",
            
            // since the goal of these tests is only to exercise the UI of the widget and form, disable as much as possible from the SDK to avoid any confounding factors that might fail or crash a test case
            "--disable-spotlight",
            "--disable-automatic-session-tracking",
            "--disable-metrickit-integration",
            "--disable-session-replay",
            "--disable-watchdog-tracking",
            "--disable-tracing",
            "--disable-swizzling",
            "--disable-network-breadcrumbs",
            "--disable-core-data-tracing",
            "--disable-network-tracking",
            "--disable-uiviewcontroller-tracing",
            "--disable-automatic-breadcrumbs",
            "--disable-anr-tracking",
            "--disable-auto-performance-tracing",
            "--disable-ui-tracing"
        ])
        continueAfterFailure = true
    }
    
    // MARK: Tests ensuring correct appearance
    
    func testUIElementsWithDefaults() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        // widget button text
        XCTAssert(app.staticTexts["Report a Bug"].exists)
        
        widgetButton.tap()
        
        // Form title
        XCTAssert(app.staticTexts["Report a Bug"].exists)
        
        // form buttons
        XCTAssert(app.staticTexts["Add a screenshot"].exists)
        XCTAssert(app.staticTexts["Cancel"].exists)
        XCTAssert(app.staticTexts["Send Bug Report"].exists)
        
        addScreenshotButton.tap()
        XCTAssert(app.staticTexts["Remove screenshot"].exists)
        
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
        XCTAssert(app.staticTexts["Report Jank"].exists)
        
        widgetButton.tap()
        
        // Form title
        XCTAssert(app.staticTexts["Jank Report"].exists)
        
        // form buttons
        XCTAssert(app.staticTexts["Report that jank"].exists)
        XCTAssert(app.staticTexts["Show us the jank"].exists)
        XCTAssert(app.staticTexts["What, me worry?"].exists)
        
        addScreenshotButton.tap()
        XCTAssert(app.staticTexts["Oof too nsfl"].exists)
        
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
        launchApp(args: ["--io.sentry.feedback.use-sentry-user"], env: [
            "--io.sentry.user.name": "ui test user",
            "--io.sentry.user.email": "ui-testing@sentry.io"
        ])
        
        widgetButton.tap()
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "ui test user")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "ui-testing@sentry.io")
    }
    
    // MARK: Tests validating happy path / successful submission
    
    func testSubmitFullyFilledForm() throws {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        
        widgetButton.tap()
        
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        sendButton.tap()
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
        
        // TODO: go to Extras view
        app.buttons["io.sentry.ui-test.button.get-feedback-envelope"].tap()
        // TODO: pull contents out of text field
        // TODO: validate contents
    }
    
    func testSubmitWithOnlyRequiredFieldsFilled() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        widgetButton.tap()
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        sendButton.tap()
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
    }
    
    // MARK: Tests validating cancellation functions correctly
    
    func testCancelFromFormByButton() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        widgetButton.tap()
        
        // fill out the fields; we'll assert later that the entered data does not reappear on subsequent displays
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        let cancelButton: XCUIElement = app.staticTexts["Cancel"]
        cancelButton.tap()
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
    }
    
    func testCancelFromFormBySwipeDown() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        widgetButton.tap()
        
        // fill out the fields; we'll assert later that the entered data does not reappear on subsequent displays
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")

        // first swipe down dismisses the keyboard that's still visible from typing the above inputs
        app.swipeDown(velocity: .fast)
        
        // the modal cancel gesture
        app.swipeDown(velocity: .fast)
        
        // the swipe dismiss animation takes an extra moment, so we need to wait for the widget to be visible again
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "", "The UITextView shouldn't have any initial text functioning as a placeholder; as UITextView has no placeholder property, the \"placeholder\" is a label on top of it.")
    }
    
    // MARK: Tests validating screenshot functionality
    
    func testAddingAndRemovingScreenshots() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        widgetButton.tap()
        addScreenshotButton.tap()
        XCTAssert(removeScreenshotButton.isHittable)
        XCTAssertFalse(addScreenshotButton.isHittable)
        removeScreenshotButton.tap()
        XCTAssert(addScreenshotButton.isHittable)
        XCTAssertFalse(removeScreenshotButton.isHittable)
    }
    
    // MARK: Tests validating error cases
    
    func testSubmitWithNoFieldsFilledDefault() throws {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        
        widgetButton.tap()
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information. Please check the following field: description."].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitWithNoFieldsFilledEmailAndMessageRequired() {
        launchApp(args: ["--io.sentry.feedback.require-email"])
        
        widgetButton.tap()
        
        XCTAssert(app.staticTexts["Thine email (Required)"].exists)
        XCTAssert(app.staticTexts["Thy name"].exists)
        XCTAssertFalse(app.staticTexts["Thy name (Required)"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information. Please check the following fields: thine email and thy complaint."].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitWithNoFieldsFilledAllRequired() throws {
        launchApp(args: [
            "--io.sentry.feedback.require-email",
            "--io.sentry.feedback.require-name"
        ])
        
        widgetButton.tap()
        
        XCTAssert(app.staticTexts["Thine email (Required)"].exists)
        XCTAssert(app.staticTexts["Thy name (Required)"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information. Please check the following fields: thy name, thine email and thy complaint."].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitWithNoFieldsFilledAllRequiredCustomLabels() throws {
        launchApp(args: [
            "--io.sentry.feedback.require-email",
            "--io.sentry.feedback.require-name"
        ])
        
        widgetButton.tap()
        
        XCTAssert(app.staticTexts["Thine email (Required)"].exists)
        XCTAssert(app.staticTexts["Thy name (Required)"].exists)
        XCTAssert(app.staticTexts["Thy complaint (Required)"].exists)
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information. Please check the following fields: thy name, thine email and thy complaint."].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitOnlyWithOptionalFieldsFilled() throws {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        
        widgetButton.tap()
        
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        XCTAssert(app.staticTexts["You must provide all required information. Please check the following field: description."].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmissionErrorThenSuccessAfterFixingIssues() {
        launchApp(args: ["--io.sentry.feedback.all-defaults"])
        widgetButton.tap()
        
        sendButton.tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        
        app.buttons["OK"].tap()
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        sendButton.tap()
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
    }
    
    // MARK: Private
    
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
    
    var addScreenshotButton: XCUIElement {
        app.buttons["io.sentry.feedback.form.add-screenshot"]
    }
    
    var removeScreenshotButton: XCUIElement {
        app.buttons["io.sentry.feedback.form.remove-screenshot"]
    }
}

//swiftlint:enable todo
