import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) @testable import Sentry

@testable import SentryObjCCompat
import UIKit
import XCTest

final class SentryObjCCompatUserFeedbackConfigurationTests: XCTestCase {

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

    func testCallbacks_whenWrappingExistingConfiguration_shouldExposeWrappedCallbacks() throws {
        // -- Arrange --
        let wrappedConfiguration = SentryUserFeedbackConfiguration()
        var callbackCount = 0
        wrappedConfiguration.onFormOpen = { callbackCount += 1 }
        wrappedConfiguration.onFormClose = { callbackCount += 1 }
        wrappedConfiguration.onSubmitSuccess = { info in
            if info["message"] as? String == "hello" {
                callbackCount += 1
            }
        }
        wrappedConfiguration.onSubmitError = { error in
            let nsError = error as NSError
            if nsError.code == 1 {
                callbackCount += 1
            }
        }
        let configuration = SentryObjCUserFeedbackConfiguration(wrappedConfiguration)

        // -- Act --
        let onFormOpen = try XCTUnwrap(configuration.onFormOpen)
        let onFormClose = try XCTUnwrap(configuration.onFormClose)
        let onSubmitSuccess = try XCTUnwrap(configuration.onSubmitSuccess)
        let onSubmitError = try XCTUnwrap(configuration.onSubmitError)
        onFormOpen()
        onFormClose()
        onSubmitSuccess(["message": "hello"])
        onSubmitError(NSError(domain: "io.sentry.test", code: 1, userInfo: nil))

        // -- Assert --
        XCTAssertEqual(callbackCount, 4)
    }

    func testConfigurationBuilders_whenWrappingExistingConfiguration_shouldExposeWrappedBuilders() throws {
        // -- Arrange --
        let wrappedConfiguration = SentryUserFeedbackConfiguration()
        wrappedConfiguration.configureForm = { form in
            form.formTitle = "Existing Form"
        }
        wrappedConfiguration.configureTheme = { theme in
            theme.fontFamily = "Helvetica"
        }
        let configuration = SentryObjCUserFeedbackConfiguration(wrappedConfiguration)
        let formConfiguration = SentryObjCUserFeedbackFormConfiguration()
        let themeConfiguration = SentryObjCUserFeedbackThemeConfiguration()

        // -- Act --
        let configureForm = try XCTUnwrap(configuration.configureForm)
        let configureTheme = try XCTUnwrap(configuration.configureTheme)
        configureForm(formConfiguration)
        configureTheme(themeConfiguration)

        // -- Assert --
        XCTAssertEqual(formConfiguration.formTitle, "Existing Form")
        XCTAssertEqual(themeConfiguration.fontFamily, "Helvetica")
    }

    func testConfigureUserFeedback_whenWrappingExistingOptions_shouldExposeWrappedCallback() throws {
        // -- Arrange --
        let wrappedOptions = Options()
        wrappedOptions.configureUserFeedback = { configuration in
            configuration.animations = false
        }
        let options = SentryObjCOptions(wrappedOptions)
        let configuration = SentryObjCUserFeedbackConfiguration()

        // -- Act --
        let configureUserFeedback = try XCTUnwrap(options.configureUserFeedback)
        configureUserFeedback(configuration)

        // -- Assert --
        XCTAssertFalse(configuration.animations)
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
