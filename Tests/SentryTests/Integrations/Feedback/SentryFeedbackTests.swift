import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryFeedbackTests: XCTestCase {
    private typealias FeedbackTestCaseConfiguration = (requiresName: Bool, requiresEmail: Bool, nameInput: String?, emailInput: String?, messageInput: String?, includeScreenshot: Bool)
    private typealias FeedbackTestCase = (config: FeedbackTestCaseConfiguration, shouldValidate: Bool, expectedSubmitButtonAccessibilityHint: String)
    
    private class Fixture {
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
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", attachments: [Data()])
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")
        
        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "application/png")
    }
    
    func testSerializeCustomFeedback() throws {
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", source: .custom, attachments: [Data()])
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "custom")
        
        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "application/png")
    }
    
    func testSerializeWithAssociatedEventID() throws {
        let eventID = SentryId()
        
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", source: .custom, associatedEventId: eventID, attachments: [Data()])
        
        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "custom")
        XCTAssertEqual(try XCTUnwrap(serialization["associated_event_id"] as? String), eventID.sentryIdString)
        
        let attachments = sut.attachmentsForEnvelope()
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
        
        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 0)
    }
        
    private let inputCombinations: [FeedbackTestCase] = [
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

            switch viewModel.validate() {
            case .success(let hint):
                XCTAssert(input.shouldValidate)
                XCTAssertEqual(hint, input.expectedSubmitButtonAccessibilityHint, testCaseDescription())
            case .failure(let error):
                XCTAssertFalse(input.shouldValidate, error.description + "; " + testCaseDescription())
            }

        }
    }
    
    func testFeedbackNotSubjectToSampling() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.sampleRate = 0.0 // Sample rate that would normally filter out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)

        let client = SentryClient(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())),
            deleteOldEnvelopeItems: false,
            threadInspector: TestThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna"))
        )
        let hub = TestHub(client: client, andScope: nil)

        SentrySDKInternal.setCurrentHub(hub)
        
        let feedback = SentryFeedback(
            message: "Test feedback message",
            name: "Test User",
            email: "test@example.com",
            source: .widget
        )

        SentrySDK.capture(feedback: feedback)
        
        // Verify that the feedback was captured and sent despite the 0.0 sample rate
        let lastSentEventArguments = try XCTUnwrap(transportAdapter.sendEventWithTraceStateInvocations.last)
        let capturedFeedback = try XCTUnwrap(lastSentEventArguments.event)

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypeFeedback)
    }
    
    func testFeedbackNotSubjectToBeforeSendFiltering() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.beforeSend = { _ in return nil } // beforeSend that filters out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)

        let client = SentryClient(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())),
            deleteOldEnvelopeItems: false,
            threadInspector: TestThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna"))
        )
        let hub = TestHub(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        
        let feedback = SentryFeedback(
            message: "Test feedback message",
            name: "Test User", 
            email: "test@example.com",
            source: .widget
        )

        SentrySDK.capture(feedback: feedback)
        
        // Verify that the feedback was captured and sent despite beforeSend returning nil
        let lastSentEventArguments = try XCTUnwrap(transportAdapter.sendEventWithTraceStateInvocations.last)
        let capturedFeedback = try XCTUnwrap(lastSentEventArguments.event)

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypeFeedback)
    }
    
    func testFeedbackWithSamplingAndBeforeSendFilteringCombined() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.sampleRate = 0.5 // Partial sampling
        options.beforeSend = { _ in return nil } // beforeSend that filters out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)

        let client = SentryClient(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())),
            deleteOldEnvelopeItems: false,
            threadInspector: TestThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna"))
        )
        let hub = TestHub(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)

        struct UserInfo {
            var email: String?
        }
        
        let userInfo = UserInfo(email: nil)
        let emailString = String(userInfo.email ?? "newanonymous@example.com")
        
        let feedback = SentryFeedback(
            message: "messageString",
            name: "nameString",
            email: emailString,
            source: .widget
        )

        SentrySDK.capture(feedback: feedback)
        
        // Verify that the feedback was captured and sent despite both sampling and beforeSend filtering
        let lastSentEventArguments = try XCTUnwrap(transportAdapter.sendEventWithTraceStateInvocations.last)
        let capturedFeedback = try XCTUnwrap(lastSentEventArguments.event)

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypeFeedback)
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
