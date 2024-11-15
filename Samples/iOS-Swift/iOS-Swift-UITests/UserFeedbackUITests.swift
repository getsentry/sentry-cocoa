import XCTest

class UserFeedbackUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    override func setUp() {
        super.setUp()
        app.launchArguments.append(contentsOf: [
            "--io.sentry.iOS-Swift.auto-inject-user-feedback-widget",
            "--io.sentry.iOS-Swift.user-feedback.all-defaults",
        ])
        launchApp()
    }
    
    func testSubmitFullyFilledForm() throws {
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        widgetButton.tap()
        
        let nameField: XCUIElement = app.textFields["Your Name"]
        nameField.tap()
        nameField.typeText("Andrew")
        
        let emailField: XCUIElement = app.textFields["your.email@example.org"]
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        let messageTextView: XCUIElement = app.textViews["What's the bug? What did you expect?"]
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
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        widgetButton.tap()
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testSubmitWithOnlyRequiredFieldsFilled() {
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        widgetButton.tap()
        
        let messageTextView: XCUIElement = app.textViews["What's the bug? What did you expect?"]
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
    }
    
    func testSubmitOnlyWithOptionalFieldsFilled() throws {
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        widgetButton.tap()
        
        let nameField: XCUIElement = app.textFields["Your Name"]
        nameField.tap()
        nameField.typeText("Andrew")
        
        let emailField: XCUIElement = app.textFields["your.email@example.org"]
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        app.staticTexts["Send Bug Report"].tap()
        
        XCTAssert(app.staticTexts["Error"].exists)
        
        app.buttons["OK"].tap()
    }
    
    func testCancelFromFormByButton() {
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        
        widgetButton.tap()
        
        // fill out the fields; we'll assert later that the entered data does not reappear on subsequent displays
        let nameField: XCUIElement = app.textFields["Your Name"]
        nameField.tap()
        nameField.typeText("Andrew")
        
        let emailField: XCUIElement = app.textFields["your.email@example.org"]
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        let messageTextView: XCUIElement = app.textViews["What's the bug? What did you expect?"]
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
        let widgetButton: XCUIElement = app.staticTexts["Report a Bug"]
        
        widgetButton.tap()
        
        // fill out the fields; we'll assert later that the entered data does not reappear on subsequent displays
        let nameField: XCUIElement = app.textFields["Your Name"]
        nameField.tap()
        nameField.typeText("Andrew")
        
        let emailField: XCUIElement = app.textFields["your.email@example.org"]
        emailField.tap()
        emailField.typeText("andrew.mcknight@sentry.io")
        
        let messageTextView: XCUIElement = app.textViews["What's the bug? What did you expect?"]
        messageTextView.tap()
        messageTextView.typeText("UITest user feedback")
        
        // the cancel gesture
        app.swipeDown(velocity: .fast)
        
        // displaying the form again ensures the widget button still works afterwards; also assert that the fields are in their default state to ensure the entered data is not persisted between displays
        
        XCTAssert(widgetButton.waitForExistence(timeout: 1))
        widgetButton.tap()
        
        // the placeholder text is returned for XCUIElement.value
        XCTAssertEqual(try XCTUnwrap(nameField.value as? String), "Your Name")
        XCTAssertEqual(try XCTUnwrap(emailField.value as? String), "your.email@example.org")
        
        // the UITextView doesn't hav a placeholder, it's a label on top of it. so it is actually empty
        XCTAssertEqual(try XCTUnwrap(messageTextView.value as? String), "")
    }
}
