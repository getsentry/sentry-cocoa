import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import UIKit
import XCTest

final class SentryObjCCompatUserFeedbackConfigurationTests: XCTestCase {

    func testConfigureUserFeedback_whenSet_shouldConfigureWrappedOptions() throws {
        // -- Arrange --
        let options = SentryObjCOptions()
        let customButton = UIButton()
        options.configureUserFeedback = { configuration in
            configuration.animations = false
            configuration.useShakeGesture = true
            configuration.showFormForScreenshots = true
            configuration.customButton = customButton
            configuration.tags = ["feature": "feedback"]
            configuration.configureForm = { form in
                form.useSentryUser = false
                form.showBranding = false
                form.formTitle = "Jank Report"
                form.messagePlaceholder = "Describe the jank"
                form.isNameRequired = true
                form.isEmailRequired = true
                form.validationErrorMessage = { multipleErrors in
                    multipleErrors ? "Many errors" : "One error"
                }
            }
            configuration.configureTheme = { theme in
                theme.fontFamily = "Helvetica"
                theme.foreground = .red
                theme.background = .blue
                theme.outlineStyle = SentryObjCUserFeedbackFormElementOutlineStyle(
                    color: .purple,
                    cornerRadius: 10,
                    outlineWidth: 2
                )
            }
        }
        let configureUserFeedback = try XCTUnwrap(options.wrapped.configureUserFeedback)
        let wrappedConfiguration = SentryUserFeedbackConfiguration()

        // -- Act --
        configureUserFeedback(wrappedConfiguration)

        // -- Assert --
        XCTAssertFalse(wrappedConfiguration.animations)
        XCTAssertTrue(wrappedConfiguration.useShakeGesture)
        XCTAssertTrue(wrappedConfiguration.showFormForScreenshots)
        XCTAssertIdentical(wrappedConfiguration.customButton, customButton)
        XCTAssertEqual(wrappedConfiguration.tags?["feature"] as? String, "feedback")

        let formConfiguration = SentryUserFeedbackFormConfiguration()
        let configureForm = try XCTUnwrap(wrappedConfiguration.configureForm)
        configureForm(formConfiguration)
        XCTAssertFalse(formConfiguration.useSentryUser)
        XCTAssertFalse(formConfiguration.showBranding)
        XCTAssertEqual(formConfiguration.formTitle, "Jank Report")
        XCTAssertEqual(formConfiguration.messagePlaceholder, "Describe the jank")
        XCTAssertTrue(formConfiguration.isNameRequired)
        XCTAssertTrue(formConfiguration.isEmailRequired)
        XCTAssertEqual(formConfiguration.validationErrorMessage(false), "One error")
        XCTAssertEqual(formConfiguration.validationErrorMessage(true), "Many errors")

        let themeConfiguration = SentryUserFeedbackThemeConfiguration()
        let configureTheme = try XCTUnwrap(wrappedConfiguration.configureTheme)
        configureTheme(themeConfiguration)
        XCTAssertEqual(themeConfiguration.fontFamily, "Helvetica")
        XCTAssertTrue(themeConfiguration.foreground.isEqual(UIColor.red))
        XCTAssertTrue(themeConfiguration.background.isEqual(UIColor.blue))
        XCTAssertTrue(themeConfiguration.outlineStyle.color.isEqual(UIColor.purple))
        XCTAssertEqual(themeConfiguration.outlineStyle.cornerRadius, 10)
        XCTAssertEqual(themeConfiguration.outlineStyle.outlineWidth, 2)
    }

    func testCallbacks_whenSet_shouldForwardToWrappedConfiguration() throws {
        // -- Arrange --
        let configuration = SentryObjCUserFeedbackConfiguration()
        var callbackCount = 0
        configuration.onFormOpen = { callbackCount += 1 }
        configuration.onFormClose = { callbackCount += 1 }
        configuration.onSubmitSuccess = { info in
            if info["message"] as? String == "hello" {
                callbackCount += 1
            }
        }
        configuration.onSubmitError = { error in
            if error.code == 1 {
                callbackCount += 1
            }
        }

        // -- Act --
        let onFormOpen = try XCTUnwrap(configuration.wrapped.onFormOpen)
        let onFormClose = try XCTUnwrap(configuration.wrapped.onFormClose)
        let onSubmitSuccess = try XCTUnwrap(configuration.wrapped.onSubmitSuccess)
        let onSubmitError = try XCTUnwrap(configuration.wrapped.onSubmitError)
        onFormOpen()
        onFormClose()
        onSubmitSuccess(["message": "hello"])
        onSubmitError(NSError(domain: "io.sentry.test", code: 1, userInfo: nil))

        // -- Assert --
        XCTAssertEqual(callbackCount, 4)
    }

    func testThemeOutlineStyle_whenMutated_shouldMutateWrappedStyle() {
        // -- Arrange --
        let theme = SentryObjCUserFeedbackThemeConfiguration()
        let outlineStyle = theme.outlineStyle

        // -- Act --
        outlineStyle.color = .orange
        outlineStyle.cornerRadius = 7
        outlineStyle.outlineWidth = 3

        // -- Assert --
        XCTAssertTrue(theme.wrapped.outlineStyle.color.isEqual(UIColor.orange))
        XCTAssertEqual(theme.wrapped.outlineStyle.cornerRadius, 7)
        XCTAssertEqual(theme.wrapped.outlineStyle.outlineWidth, 3)
    }
}
#endif
