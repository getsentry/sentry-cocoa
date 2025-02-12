import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@testable import Sentry
import XCTest

class SentryFeedbackTests: XCTestCase {
    typealias FeedbackTestCaseConfiguration = (requiresName: Bool, requiresEmail: Bool, nameInput: String?, emailInput: String?, messageInput: String?, includeScreenshot: Bool)
    typealias FeedbackTestCase = (config: FeedbackTestCaseConfiguration, shouldValidate: Bool, expectedSubmitButtonAccessibilityHint: String)
    
    class Fixture {
        class TestFormDelegate: NSObject, SentryUserFeedbackFormDelegate {
            func finished(with feedback: Sentry.SentryFeedback?) {
                // no-op
            }
        }
        let config: SentryUserFeedbackConfiguration
        let testCaseConfig: FeedbackTestCaseConfiguration
        let formDelegate = TestFormDelegate()
        lazy var controller = {
            let controller = SentryUserFeedbackFormController(config: config, delegate: formDelegate, screenshot: self.testCaseConfig.includeScreenshot ? UIImage() : nil)
            config.configureForm?(config.formConfig) // this is needed to actually get the configured test photo picker into the controller. usually done by the driver
            return controller
        }()
                
        init(config: SentryUserFeedbackConfiguration, testCaseConfig: FeedbackTestCaseConfiguration) {
            self.config = config
            self.testCaseConfig = testCaseConfig
        }
    }
    
    func testSerializeWithAllFields() throws {
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", screenshot: Data())
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")
        
        let attachments = sut.attachments()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "application/png")
    }
    
    func testSerializeWithNoOptionalFields() throws {
        let sut = SentryFeedback(message: "Test feedback message", name: nil, email: nil)
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertNil(serialization["name"])
        XCTAssertNil(serialization["contact_email"])
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")
        
        let attachments = sut.attachments()
        XCTAssertEqual(attachments.count, 0)
    }
        
    let inputCombinations: [FeedbackTestCase] = [
        // base case: don't require name or email, don't input a name or email, don't input a message or screenshot
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        // set a screenshot
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        // set a message
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name or email address with message: Test message."),
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name or email address including attached screenshot with message: Test message."),
        // set an email address
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name at test@email.value with message: Test message."),
        (config: (requiresName: false, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name at test@email.value including attached screenshot with message: Test message."),
        // set a name
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester with no email address with message: Test message."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester with no email address including attached screenshot with message: Test message."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value with message: Test message."),
        (config: (requiresName: false, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value including attached screenshot with message: Test message."),
        // require email address
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name at test@email.value with message: Test message."),
        (config: (requiresName: false, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback with no name at test@email.value including attached screenshot with message: Test message."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value with message: Test message."),
        (config: (requiresName: false, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value including attached screenshot with message: Test message."),
        // require name
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: name and description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: name and description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: name and description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: name and description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: false, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester with no email address with message: Test message."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester with no email address including attached screenshot with message: Test message."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value with message: Test message."),
        (config: (requiresName: true, requiresEmail: false, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value including attached screenshot with message: Test message."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following fields: email and description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: true, nameInput: nil, emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: name."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: nil, messageInput: "Test message", includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: email."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: false), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: nil, includeScreenshot: true), shouldValidate: false, expectedSubmitButtonAccessibilityHint: "You must provide all required information before submitting. Please check the following field: description."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: false), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value with message: Test message."),
        (config: (requiresName: true, requiresEmail: true, nameInput: "tester", emailInput: "test@email.value", messageInput: "Test message", includeScreenshot: true), shouldValidate: true, expectedSubmitButtonAccessibilityHint: "Will submit feedback for tester at test@email.value including attached screenshot with message: Test message.")
    ]
    
    func testSubmitButtonAccessibilityHint() {
        for input in inputCombinations {
            let config = SentryUserFeedbackConfiguration()
            config.configureForm = {
                $0.isNameRequired = input.config.requiresName
                $0.isEmailRequired = input.config.requiresEmail
            }
            let fixture = Fixture(config: config, testCaseConfig: input.config)
            let viewModel = fixture.controller.viewModel
            viewModel.fullNameTextField.text = input.config.nameInput
            viewModel.emailTextField.text = input.config.emailInput
            viewModel.messageTextView.text = input.config.messageInput
            func testCaseDescription() -> String {
                "(config: (requiresName: \(input.config.requiresName), requiresEmail: \(input.config.requiresEmail), nameInput: \(input.config.nameInput == nil ? "nil" : "\"\(input.config.nameInput!)\""), emailInput: \(input.config.emailInput == nil ? "nil" : "\"\(input.config.emailInput!)\""), messageInput: \(input.config.messageInput == nil ? "nil" : "\"\(input.config.messageInput!)\""), includeScreenshot: \(input.config.includeScreenshot)), expectedSubmitButtonAccessibilityHint: \(input.expectedSubmitButtonAccessibilityHint)"
            }
            SentryLog.withOutLogs {
                switch viewModel.validate() {
                case .success(let hint):
                    XCTAssert(input.shouldValidate)
                    XCTAssertEqual(hint, input.expectedSubmitButtonAccessibilityHint, testCaseDescription())
                case .failure(let error):
                    XCTAssertFalse(input.shouldValidate, error.description + "; " + testCaseDescription())
                }
            }
        }
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
