import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryFeedbackTests: XCTestCase {
    private typealias FeedbackTestCaseConfiguration = (requiresName: Bool, requiresEmail: Bool, nameInput: String?, emailInput: String?, messageInput: String?, includeScreenshot: Bool)
    private typealias FeedbackTestCase = (config: FeedbackTestCaseConfiguration, shouldValidate: Bool, expectedSubmitButtonAccessibilityHint: String)
    
    private class Fixture {
        let config: SentryFeedbackFormConfig
        let testCaseConfig: FeedbackTestCaseConfiguration
        lazy var controller = SentryUserFeedbackFormController(config: config, image: self.testCaseConfig.includeScreenshot ? UIImage() : nil)

        init(config: SentryFeedbackFormConfig, testCaseConfig: FeedbackTestCaseConfiguration) {
            self.config = config
            self.testCaseConfig = testCaseConfig
        }
    }

    func testFeedbackFormConfigDefaults_shouldMatchLegacyFormDefaults() {
        let sut = SentryFeedbackFormConfig()
        let legacy = SentryUserFeedbackFormConfiguration()

        XCTAssertEqual(sut.formTitle, legacy.formTitle)
        XCTAssertEqual(sut.showName, legacy.showName)
        XCTAssertEqual(sut.showEmail, legacy.showEmail)
        XCTAssertEqual(sut.isNameRequired, legacy.isNameRequired)
        XCTAssertEqual(sut.isEmailRequired, legacy.isEmailRequired)
        XCTAssertEqual(sut.nameLabel, legacy.nameLabel)
        XCTAssertEqual(sut.emailLabel, legacy.emailLabel)
        XCTAssertEqual(sut.messageLabel, legacy.messageLabel)
        XCTAssertEqual(sut.namePlaceholder, legacy.namePlaceholder)
        XCTAssertEqual(sut.emailPlaceholder, legacy.emailPlaceholder)
        XCTAssertEqual(sut.messagePlaceholder, legacy.messagePlaceholder)
        XCTAssertEqual(sut.submitButtonLabel, legacy.submitButtonLabel)
        XCTAssertEqual(sut.cancelButtonLabel, legacy.cancelButtonLabel)
        XCTAssertEqual(sut.showBranding, legacy.showBranding)
        XCTAssertEqual(sut.useSentryUser, legacy.useSentryUser)
    }

    func testFeedbackFormConfig_whenCreatedFromPreparedLegacyConfig_shouldMapValues() {
        let legacy = SentryUserFeedbackConfiguration()
        legacy.animations = false
        var didOpen = false
        var didClose = false
        var didSubmit = false
        var didFail = false
        let dynamicBackground = UIColor { _ in .purple }
        legacy.onFormOpen = { didOpen = true }
        legacy.onFormClose = { didClose = true }
        legacy.onSubmitSuccess = { _ in didSubmit = true }
        legacy.onSubmitError = { _ in didFail = true }
        legacy.configureForm = { form in
            form.formTitle = "Custom title"
            form.showName = false
            form.showEmail = false
            form.isNameRequired = true
            form.isEmailRequired = true
            form.nameLabel = "Custom name"
            form.emailLabel = "Custom email"
            form.messageLabel = "Custom message"
            form.namePlaceholder = "Name placeholder"
            form.emailPlaceholder = "Email placeholder"
            form.messagePlaceholder = "Message placeholder"
            form.submitButtonLabel = "Submit"
            form.cancelButtonLabel = "Dismiss"
            form.showBranding = false
            form.useSentryUser = false
        }
        legacy.configureTheme = { theme in
            theme.background = dynamicBackground
        }

        legacy.configureForm?(legacy.formConfig)
        legacy.configureTheme?(legacy.theme)

        let sut = SentryFeedbackFormConfig(userFeedbackConfiguration: legacy)

        XCTAssertFalse(sut.animations)
        XCTAssertEqual(sut.formTitle, "Custom title")
        XCTAssertFalse(sut.showName)
        XCTAssertFalse(sut.showEmail)
        XCTAssertTrue(sut.isNameRequired)
        XCTAssertTrue(sut.isEmailRequired)
        XCTAssertEqual(sut.nameLabel, "Custom name")
        XCTAssertEqual(sut.emailLabel, "Custom email")
        XCTAssertEqual(sut.messageLabel, "Custom message")
        XCTAssertEqual(sut.namePlaceholder, "Name placeholder")
        XCTAssertEqual(sut.emailPlaceholder, "Email placeholder")
        XCTAssertEqual(sut.messagePlaceholder, "Message placeholder")
        XCTAssertEqual(sut.submitButtonLabel, "Submit")
        XCTAssertEqual(sut.cancelButtonLabel, "Dismiss")
        XCTAssertFalse(sut.showBranding)
        XCTAssertFalse(sut.useSentryUser)
        XCTAssertIdentical(sut.theme.background, dynamicBackground)

        sut.onFormOpen?()
        sut.onFormClose?()
        sut.onSubmitSuccess?([:])
        sut.onSubmitError?(NSError(domain: "io.sentry.test", code: 0))

        XCTAssertTrue(didOpen)
        XCTAssertTrue(didClose)
        XCTAssertTrue(didSubmit)
        XCTAssertTrue(didFail)
    }

    func testFormLifecycle_whenFormAppears_shouldCallOpenOnce() {
        let config = SentryFeedbackFormConfig()
        var openCalls = 0
        config.onFormOpen = { openCalls += 1 }
        let sut = SentryUserFeedbackFormController(config: config)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        XCTAssertEqual(openCalls, 1)
    }

    func testFormLifecycle_whenPresentationDismisses_shouldCallCloseOnce() {
        let config = SentryFeedbackFormConfig()
        var closeCalls = 0
        var internalCloseCalls = 0
        config.onFormClose = { closeCalls += 1 }
        let sut = SentryUserFeedbackFormController(config: config)
        sut.onDidClose = { internalCloseCalls += 1 }
        let presentationController = UIPresentationController(presentedViewController: sut, presenting: nil)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.presentationControllerDidDismiss(presentationController)
        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertEqual(closeCalls, 1)
        XCTAssertEqual(internalCloseCalls, 1)
    }

    func testSubmitFeedback_whenValid_shouldCallSubmitSuccess() {
        let config = SentryFeedbackFormConfig()
        var submittedData: [String: Any]?
        config.onSubmitSuccess = { submittedData = $0 }
        let sut = SentryUserFeedbackFormController(config: config)

        sut.viewModel.messageTextView.text = "It broke"
        sut.submitFeedback()

        XCTAssertEqual(submittedData?["message"] as? String, "It broke")
    }

    func testSubmitFeedback_whenInvalid_shouldCallSubmitErrorAndNotClose() throws {
        let config = SentryFeedbackFormConfig()
        var submitErrors = [NSError]()
        var closeCalls = 0
        config.onSubmitError = { error in
            submitErrors.append(error as NSError)
        }
        config.onFormClose = { closeCalls += 1 }
        let sut = SentryUserFeedbackFormController(config: config)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.submitFeedback()

        let error = try XCTUnwrap(submitErrors.first)
        XCTAssertEqual(error.code, 1)
        XCTAssertEqual(closeCalls, 0)
    }
    
    func testSerializeWithAllFields() throws {
        let attachment = Attachment(data: Data(), filename: "screenshot.png", contentType: "image/png")
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", attachments: [attachment])

        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "widget")

        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "image/png")
    }
    
    func testSerializeCustomFeedback() throws {
        let attachment = Attachment(data: Data(), filename: "screenshot.png", contentType: "image/png")
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", source: .custom, attachments: [attachment])

        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "custom")

        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "image/png")
    }
    
    func testSerializeWithAssociatedEventID() throws {
        let eventID = SentryId()
        let attachment = Attachment(data: Data(), filename: "screenshot.png", contentType: "image/png")
        let sut = SentryFeedback(message: "Test feedback message", name: "Test feedback provider", email: "test-feedback-provider@sentry.io", source: .custom, associatedEventId: eventID, attachments: [attachment])

        let serialization = sut.serialize()
        XCTAssertEqual(try XCTUnwrap(serialization["message"] as? String), "Test feedback message")
        XCTAssertEqual(try XCTUnwrap(serialization["name"] as? String), "Test feedback provider")
        XCTAssertEqual(try XCTUnwrap(serialization["contact_email"] as? String), "test-feedback-provider@sentry.io")
        XCTAssertEqual(try XCTUnwrap(serialization["source"] as? String), "custom")
        XCTAssertEqual(try XCTUnwrap(serialization["associated_event_id"] as? String), eventID.sentryIdString)

        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try XCTUnwrap(attachments.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(attachments.first).contentType, "image/png")
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

    func testMultipleAttachments() throws {
        let screenshot = Attachment(data: Data("screenshot".utf8), filename: "screenshot.png", contentType: "image/png")
        let logFile = Attachment(data: Data("log content".utf8), filename: "app.log", contentType: "text/plain")
        let videoFile = Attachment(data: Data("video".utf8), filename: "recording.mp4", contentType: "video/mp4")

        let sut = SentryFeedback(message: "Test feedback with multiple attachments", name: "Test User", email: "test@example.com", attachments: [screenshot, logFile, videoFile])

        let attachments = sut.attachmentsForEnvelope()
        XCTAssertEqual(attachments.count, 3)
        XCTAssertEqual(attachments[0].filename, "screenshot.png")
        XCTAssertEqual(attachments[0].contentType, "image/png")
        XCTAssertEqual(attachments[1].filename, "app.log")
        XCTAssertEqual(attachments[1].contentType, "text/plain")
        XCTAssertEqual(attachments[2].filename, "recording.mp4")
        XCTAssertEqual(attachments[2].contentType, "video/mp4")
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
    
    func testSubmitButtonAccessibilityHint() throws {
        for input in inputCombinations {
            let config = SentryFeedbackFormConfig()
            config.isNameRequired = input.config.requiresName
            config.isEmailRequired = input.config.requiresEmail
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
                XCTAssertTrue(input.shouldValidate)
                XCTAssertEqual(hint, input.expectedSubmitButtonAccessibilityHint, testCaseDescription())
            case .failure(let error):
                let errorDescription = try XCTUnwrap(error.errorDescription)
                XCTAssertFalse(input.shouldValidate, errorDescription + "; " + testCaseDescription())
            }

        }
    }
    
    func testFeedbackNotSubjectToSampling() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.sampleRate = 0.0 // Sample rate that would normally filter out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)
        let dateProvider = TestCurrentDateProvider()

        let client = SentryClientInternal(
            options: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )),
            threadInspector: TestDefaultThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna")),
            eventContextEnricher: TestEventContextEnricher(),
            crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper,
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache
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

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypes.feedback)
    }
    
    func testFeedbackNotSubjectToBeforeSendFiltering() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.beforeSend = { _ in return nil } // beforeSend that filters out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)
        let dateProvider = TestCurrentDateProvider()

        let client = SentryClientInternal(
            options: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )),
            threadInspector: TestDefaultThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna")),
            eventContextEnricher: TestEventContextEnricher(),
            crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper,
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache
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

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypes.feedback)
    }
    
    func testFeedbackWithSamplingAndBeforeSendFilteringCombined() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFeedbackTests")
        options.sampleRate = 0.5 // Partial sampling
        options.beforeSend = { _ in return nil } // beforeSend that filters out all events

        let transport = TestTransport()
        let transportAdapter = TestTransportAdapter(transports: [transport], options: options)
        let dateProvider = TestCurrentDateProvider()
        
        let client = SentryClientInternal(
            options: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: try XCTUnwrap(SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )),
            threadInspector: TestDefaultThreadInspector.instance,
            debugImageProvider: TestDebugImageProvider(),
            random: TestRandom(value: 1.0),
            locale: Locale(identifier: "en_US"),
            timezone: try XCTUnwrap(TimeZone(identifier: "Europe/Vienna")),
            eventContextEnricher: TestEventContextEnricher(),
            crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper,
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache
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

        XCTAssertEqual(capturedFeedback.type, SentryEnvelopeItemTypes.feedback)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
