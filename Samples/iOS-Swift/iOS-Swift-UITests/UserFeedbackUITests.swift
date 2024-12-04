import XCTest

class UserFeedbackUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    override func setUp() {
        super.setUp()
        app.launchArguments.append(contentsOf: [
            "--io.sentry.iOS-Swift.auto-inject-user-feedback-widget",
            "--io.sentry.iOS-Swift.user-feedback.all-defaults",
            "--io.sentry.feedback.no-animations"
        ])
        launchApp()
    }
    
    func testSubmitFullyFilledForm() throws {
        widgetButton.tap()
        
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        app.staticTexts["Send Bug Report"].tap()
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        // the UITextView doesn't hav a placeholder, it's a label on top of it. so it is actually empty
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "")
    }
    
    func testSubmitWithNoFieldsFilled() throws {
        widgetButton.tap()
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitWithOnlyRequiredFieldsFilled() {
        widgetButton.tap()
        
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
    }
    
    func testSubmitOnlyWithOptionalFieldsFilled() throws {
        widgetButton.tap()
        
        nameField.tap()
        nameField.typeText("Andrew")
        
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testCancelFromFormByButton() {
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
        
        // the UITextView doesn't hav a placeholder, it's a label on top of it. so it is actually empty
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "")
    }
    
    func testCancelFromFormBySwipeDown() {
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
        // the cancel gesture
        app.swipeDown(velocity: .fast)
        
        // the swipe dismiss animation takes an extra moment, so we need to wait for the widget to be visible again
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        // the UITextView doesn't hav a placeholder, it's a label on top of it. so it is actually empty
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "")
    }
    
    func testAddingAndRemovingScreenshots() {
        widgetButton.tap()
        addScreenshotButton.tap()
        XCTAssert(removeScreenshotButton.isHittable)
        XCTAssertFalse(addScreenshotButton.isHittable)
        removeScreenshotButton.tap()
        XCTAssert(addScreenshotButton.isHittable)
        XCTAssertFalse(removeScreenshotButton.isHittable)
    }
    
    // MARK: Private
    
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
