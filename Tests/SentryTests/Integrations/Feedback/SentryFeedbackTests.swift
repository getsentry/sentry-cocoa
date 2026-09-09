import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import PhotosUI
import UniformTypeIdentifiers
import XCTest

class SentryFeedbackTests: XCTestCase {
#if !targetEnvironment(macCatalyst)
    private static let mockWindowScene: UIWindowScene = MockUIWindowScene()
#endif

    private typealias FeedbackTestCaseConfiguration = (requiresName: Bool, requiresEmail: Bool, nameInput: String?, emailInput: String?, messageInput: String?, includeScreenshot: Bool)
    private typealias FeedbackTestCase = (config: FeedbackTestCaseConfiguration, shouldValidate: Bool, expectedSubmitButtonAccessibilityHint: String)

    private class Fixture {
        let config: SentryUserFeedbackConfiguration
        let testCaseConfig: FeedbackTestCaseConfiguration
        lazy var controller = SentryUserFeedbackFormController(preparedConfig: config, screenshot: self.testCaseConfig.includeScreenshot ? UIImage() : nil)

        init(config: SentryUserFeedbackConfiguration, testCaseConfig: FeedbackTestCaseConfiguration) {
            config.configureForm?(config.formConfig)
            config.configureTheme?(config.theme)
            #if !SDK_V10
            config._configureDarkTheme?(config.darkTheme)
            #endif
            self.config = config
            self.testCaseConfig = testCaseConfig
        }
    }

    private final class TestFormDelegate: NSObject, SentryUserFeedbackFormDelegate {
        private(set) var closeCalls = 0

        func userFeedbackFormDidClose(_ form: SentryUserFeedbackFormController) {
            closeCalls += 1
        }
    }

    private final class DismissingParentViewController: UIViewController {
        override var isBeingDismissed: Bool { true }
    }

    func testFormLifecycle_whenFormAppears_shouldCallOpenOnce() {
        let config = SentryUserFeedbackConfiguration()
        var openCalls = 0
        config.onFormOpen = { openCalls += 1 }
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()

        XCTAssertEqual(openCalls, 1)
    }

    func testFormLifecycle_whenPresentationDismisses_shouldCallCloseOnce() {
        let config = SentryUserFeedbackConfiguration()
        let delegate = TestFormDelegate()
        var closeCalls = 0
        config.onFormClose = { closeCalls += 1 }
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        sut.delegate = delegate
        let presentationController = UIPresentationController(presentedViewController: sut, presenting: nil)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.presentationControllerDidDismiss(presentationController)
        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertEqual(closeCalls, 1)
        XCTAssertEqual(delegate.closeCalls, 1)
    }

    func testFormLifecycle_whenPresentingParentDismisses_shouldCallCloseOnce() {
        let config = SentryUserFeedbackConfiguration()
        var closeCalls = 0
        config.onFormClose = { closeCalls += 1 }
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let parent = DismissingParentViewController()
        parent.addChild(sut)
        parent.view.addSubview(sut.view)
        sut.didMove(toParent: parent)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.beginAppearanceTransition(false, animated: false)
        sut.endAppearanceTransition()

        XCTAssertEqual(closeCalls, 1)
    }

    func testFormLifecycle_whenSameFormIsPresentedAgain_shouldCallHooksAgain() {
        let config = SentryUserFeedbackConfiguration()
        var openCalls = 0
        var closeCalls = 0
        config.onFormOpen = { openCalls += 1 }
        config.onFormClose = { closeCalls += 1 }
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let presentationController = UIPresentationController(presentedViewController: sut, presenting: nil)

        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.presentationControllerDidDismiss(presentationController)
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertEqual(openCalls, 2)
        XCTAssertEqual(closeCalls, 2)
    }

    func testForm_whenScreenshotSelectionEnabled_shouldShowAddScreenshotButton() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.enableScreenshot = true

        // -- Act --
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Assert --
        XCTAssertFalse(sut.viewModel.addScreenshotButton.isHidden)
        XCTAssertTrue(sut.viewModel.removeScreenshotStack.isHidden)
    }

    func testForm_whenScreenshotSelectionDisabledByDefault_shouldHideAddScreenshotButton() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()

        // -- Act --
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Assert --
        XCTAssertTrue(sut.viewModel.addScreenshotButton.isHidden)
        XCTAssertTrue(sut.viewModel.removeScreenshotStack.isHidden)
    }

#if !targetEnvironment(macCatalyst)
    func testForm_whenScreenshotStackHidden_shouldNotOccupyVerticalSpace() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.enableScreenshot = true
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let window = UIWindow(windowScene: Self.mockWindowScene)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        addTeardownBlock { [window] in
            window.isHidden = true
        }

        // -- Act --
        sut.view.layoutIfNeeded()

        // -- Assert --
        XCTAssertEqual(sut.viewModel.removeScreenshotStack.frame.height, 0)
    }
#endif

    func testForm_whenAddScreenshotLabelsConfigured_shouldUseConfiguredLabels() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.addScreenshotButtonLabel = "Attach image"
        config.formConfig.addScreenshotButtonAccessibilityLabel = "Choose an image to attach"

        // -- Act --
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Assert --
        XCTAssertEqual(sut.viewModel.addScreenshotButton.title(for: .normal), "Attach image")
        XCTAssertEqual(sut.viewModel.addScreenshotButton.accessibilityLabel, "Choose an image to attach")
    }

    func testForm_whenScreenshotLoading_shouldShowActivityIndicatorAndHideButtonTitle() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.addScreenshotButtonLabel = "Attach image"
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Act --
        sut.viewModel.setScreenshotLoading(true)

        // -- Assert --
        XCTAssertNil(sut.viewModel.addScreenshotButton.title(for: .normal))
        XCTAssertFalse(sut.viewModel.addScreenshotButton.isEnabled)
        XCTAssertFalse(sut.viewModel.submitButton.isEnabled)
        XCTAssertTrue(sut.viewModel.screenshotLoadingIndicator.isAnimating)

        // -- Act --
        sut.viewModel.setScreenshotLoading(false)

        // -- Assert --
        XCTAssertEqual(sut.viewModel.addScreenshotButton.title(for: .normal), "Attach image")
        XCTAssertTrue(sut.viewModel.addScreenshotButton.isEnabled)
        XCTAssertTrue(sut.viewModel.submitButton.isEnabled)
        XCTAssertFalse(sut.viewModel.screenshotLoadingIndicator.isAnimating)
    }

    func testMakeScreenshotErrorAlert_whenErrorTextConfigured_shouldUseConfiguredText() throws {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.screenshotErrorText = "Choose a different image."
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Act --
        let alert = sut.makeScreenshotErrorAlert()

        // -- Assert --
        XCTAssertEqual(alert.title, "Error")
        XCTAssertEqual(alert.message, "Choose a different image.")
        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(try XCTUnwrap(alert.actions.element(at: 0)).title, "OK")
    }

#if !targetEnvironment(macCatalyst)
    func testFinishLoadingScreenshot_whenLoadingFails_shouldPresentConfiguredErrorAlert() throws {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.formConfig.screenshotErrorText = "Choose a different image."
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let window = UIWindow(windowScene: Self.mockWindowScene)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        addTeardownBlock { [window] in
            window.isHidden = true
        }

        // -- Act --
        sut.finishLoadingScreenshot(nil)

        // -- Assert --
        let alert = try XCTUnwrap(sut.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Error")
        XCTAssertEqual(alert.message, "Choose a different image.")
        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(try XCTUnwrap(alert.actions.element(at: 0)).title, "OK")
    }
#endif

    func testForm_whenScreenshotProvided_shouldShowRemoveScreenshotButton() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()

        // -- Act --
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: UIImage())

        // -- Assert --
        XCTAssertTrue(sut.viewModel.addScreenshotButton.isHidden)
        XCTAssertFalse(sut.viewModel.removeScreenshotStack.isHidden)
    }

    func testSetScreenshot_whenImageSelected_shouldUseOriginalAttachment() throws {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { _ in }
        let data = try XCTUnwrap(image.pngData())
        let attachment = Attachment(data: data, filename: "selected.png", contentType: "image/png")

        // -- Act --
        sut.viewModel.setScreenshot(image: image, attachment: attachment)
        let feedback = sut.viewModel.feedbackObject()

        // -- Assert --
        XCTAssertTrue(sut.viewModel.addScreenshotButton.isHidden)
        XCTAssertFalse(sut.viewModel.removeScreenshotStack.isHidden)
        XCTAssertFalse(sut.viewModel.screenshotImageView.isAccessibilityElement)
        XCTAssertEqual(sut.viewModel.screenshotImageAspectRatioConstraint.multiplier, 2)
        let selectedAttachment = try XCTUnwrap(feedback.attachmentsForEnvelope().first)
        XCTAssertEqual(selectedAttachment.data, data)
        XCTAssertEqual(selectedAttachment.filename, "selected.png")
        XCTAssertEqual(selectedAttachment.contentType, "image/png")
    }

    func testScreenshotFilename_whenSuggestedNameHasMismatchedImageExtension_shouldReplaceExtension() {
        // -- Act --
        let filename = SentryUserFeedbackFormController.screenshotFilename(
            suggestedName: "selected.heic",
            type: .jpeg
        )

        // -- Assert --
        XCTAssertEqual(filename, "selected.jpeg")
    }

    func testScreenshotFilename_whenSuggestedNameHasMatchingImageExtension_shouldPreserveExtension() {
        // -- Act --
        let filename = SentryUserFeedbackFormController.screenshotFilename(
            suggestedName: "selected.jpeg",
            type: .jpeg
        )

        // -- Assert --
        XCTAssertEqual(filename, "selected.jpeg")
    }

    func testScreenshotFilename_whenSuggestedNameHasDottedBasename_shouldAppendExtension() {
        // -- Act --
        let filename = SentryUserFeedbackFormController.screenshotFilename(
            suggestedName: "selected.final",
            type: .jpeg
        )

        // -- Assert --
        XCTAssertEqual(filename, "selected.final.jpeg")
    }

    func testLoadSelectedScreenshot_whenHEICSelected_shouldEncodeJPEG() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("UIImage HEIC encoding requires iOS 17 or later.")
        }

        // -- Arrange --
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }
        let data = try XCTUnwrap(image.heicData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sentry-feedback-\(UUID().uuidString).heic")
        try data.write(to: url)
        addTeardownBlock {
            try FileManager.default.removeItem(at: url)
        }

        // -- Act --
        let screenshot = SentryUserFeedbackFormController.loadSelectedScreenshot(
            from: url,
            error: nil,
            filename: "selected.heic",
            contentType: "image/heic",
            maxAttachmentSize: 10 * 1_024 * 1_024
        )

        // -- Assert --
        let attachment = try XCTUnwrap(screenshot?.1)
        let attachmentData = try XCTUnwrap(attachment.data)
        XCTAssertEqual(attachment.filename, "selected.jpg")
        XCTAssertEqual(attachment.contentType, "image/jpeg")
        XCTAssertEqual(attachmentData.prefix(2), Data([0xFF, 0xD8]))
        XCTAssertNotNil(UIImage(data: attachmentData))
    }

    func testRemoveScreenshot_whenImageSelected_shouldRemoveAttachment() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        config.formConfig.enableScreenshot = true
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)
        let attachment = Attachment(data: Data(), filename: "selected.png", contentType: "image/png")
        sut.viewModel.setScreenshot(image: UIImage(), attachment: attachment)

        // -- Act --
        sut.viewModel.removeScreenshotTapped()

        // -- Assert --
        XCTAssertFalse(sut.viewModel.addScreenshotButton.isHidden)
        XCTAssertTrue(sut.viewModel.removeScreenshotStack.isHidden)
        XCTAssertTrue(sut.viewModel.feedbackObject().attachmentsForEnvelope().isEmpty)
    }

    func testMakeScreenshotPicker_shouldSelectOneImageWithoutPhotoLibraryAccess() {
        // -- Arrange --
        let config = SentryUserFeedbackConfiguration()
        let sut = SentryUserFeedbackFormController(preparedConfig: config, screenshot: nil)

        // -- Act --
        let picker = sut.makeScreenshotPicker()

        // -- Assert --
        XCTAssertEqual(picker.configuration.selectionLimit, 1)
        XCTAssertEqual(picker.configuration.filter, PHPickerFilter.images)
        XCTAssertEqual(picker.configuration.preferredAssetRepresentationMode, .compatible)
        XCTAssertNotNil(picker.delegate)
        XCTAssertNotIdentical(picker.delegate as AnyObject?, sut)
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
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
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
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
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
            binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache,
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
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
