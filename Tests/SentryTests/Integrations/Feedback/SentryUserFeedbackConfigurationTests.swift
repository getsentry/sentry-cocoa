@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS)
import UIKit

final class SentryUserFeedbackConfigurationTests: XCTestCase {
    func testApplyConfigurationBuilders_whenBuildersSet_shouldApplyBuilders() {
        let sut = SentryUserFeedbackConfiguration()
        sut.configureForm = { form in
            form.formTitle = "Custom title"
        }
        sut.configureTheme = { theme in
            theme.background = .red
        }

        sut.applyConfigurationBuilders()

        XCTAssertEqual(sut.formConfig.formTitle, "Custom title")
        XCTAssertEqual(sut.theme.background, .red)
    }

    func testCopyForPresentation_whenPresentationFieldsSet_shouldDeepCopyPresentationFields() throws {
        let sut = SentryUserFeedbackConfiguration()
        sut.animations = false
        sut.tags = ["source": "global"]
        sut.formConfig.formTitle = "Global title"
        sut.formConfig.isNameRequired = true
        sut.theme.background = .red
        sut.theme.outlineStyle = SentryUserFeedbackThemeConfiguration.SentryFormElementOutlineStyle(
            color: .green,
            cornerRadius: 7,
            outlineWidth: 3)
        sut.darkTheme.background = .black

        let result = sut.copyForPresentation()
        result.formConfig.formTitle = "Changed title"
        result.theme.background = .blue
        result.theme.outlineStyle.color = .yellow
        result.darkTheme.background = .purple

        XCTAssertNotIdentical(result, sut)
        XCTAssertFalse(result.animations)
        XCTAssertEqual(try XCTUnwrap(result.tags?["source"] as? String), "global")
        XCTAssertNotIdentical(result.formConfig, sut.formConfig)
        XCTAssertTrue(result.formConfig.isNameRequired)
        XCTAssertEqual(result.formConfig.formTitle, "Changed title")
        XCTAssertEqual(sut.formConfig.formTitle, "Global title")
        XCTAssertNotIdentical(result.theme, sut.theme)
        XCTAssertEqual(result.theme.background, .blue)
        XCTAssertEqual(sut.theme.background, .red)
        XCTAssertNotIdentical(result.theme.outlineStyle, sut.theme.outlineStyle)
        XCTAssertEqual(result.theme.outlineStyle.color, .yellow)
        XCTAssertEqual(sut.theme.outlineStyle.color, .green)
        XCTAssertNotIdentical(result.darkTheme, sut.darkTheme)
        XCTAssertEqual(result.darkTheme.background, .purple)
        XCTAssertEqual(sut.darkTheme.background, .black)
    }

    func testConfigurationForPresentation_whenNoConfigure_shouldReturnSameConfiguration() {
        let sut = SentryUserFeedbackConfiguration()

        let result = sut.configurationForPresentation(configure: nil)

        XCTAssertIdentical(result, sut)
    }

    func testConfigurationForPresentation_whenConfigureSet_shouldApplyToCopyOnly() throws {
        let sut = SentryUserFeedbackConfiguration()
        sut.animations = true
        sut.tags = ["source": "global"]
        sut.formConfig.formTitle = "Global title"
        sut.theme.background = .red

        let result = sut.configurationForPresentation { config in
            config.animations = false
            config.tags = ["source": "local"]
            config.configureForm = { form in
                form.formTitle = "Local title"
            }
            config.configureTheme = { theme in
                theme.background = .blue
            }
        }

        XCTAssertNotIdentical(result, sut)
        XCTAssertFalse(result.animations)
        XCTAssertEqual(try XCTUnwrap(result.tags?["source"] as? String), "local")
        XCTAssertEqual(result.formConfig.formTitle, "Local title")
        XCTAssertEqual(result.theme.background, .blue)
        XCTAssertTrue(sut.animations)
        XCTAssertEqual(try XCTUnwrap(sut.tags?["source"] as? String), "global")
        XCTAssertEqual(sut.formConfig.formTitle, "Global title")
        XCTAssertEqual(sut.theme.background, .red)
    }

    func testConfigurationForPresentation_whenLocalLabelsSet_shouldDeriveAccessibilityLabelsFromLocalLabels() {
        let sut = SentryUserFeedbackConfiguration()

        let result = sut.configurationForPresentation { config in
            config.configureForm = { form in
                form.submitButtonLabel = "Send Feedback"
                form.cancelButtonLabel = "Close Feedback"
                form.removeScreenshotButtonLabel = "Delete screenshot"
                form.messagePlaceholder = "Describe feedback"
                form.namePlaceholder = "Your full name"
            }
        }

        XCTAssertEqual(result.formConfig.submitButtonAccessibilityLabel, "Send Feedback")
        XCTAssertEqual(result.formConfig.cancelButtonAccessibilityLabel, "Close Feedback")
        XCTAssertEqual(result.formConfig.removeScreenshotButtonAccessibilityLabel, "Delete screenshot")
        XCTAssertEqual(result.formConfig.messageTextViewAccessibilityLabel, "Describe feedback")
        XCTAssertEqual(result.formConfig.nameTextFieldAccessibilityLabel, "Your full name")
    }

    func testConfigurationForPresentation_whenLocalForegroundSet_shouldDeriveButtonForegroundFromLocalForeground() {
        let sut = SentryUserFeedbackConfiguration()
        sut.theme.foreground = .red

        let result = sut.configurationForPresentation { config in
            config.configureTheme = { theme in
                theme.foreground = .blue
            }
        }

        XCTAssertEqual(result.theme.foreground, .blue)
        XCTAssertEqual(result.theme.buttonForeground, .blue)
        XCTAssertEqual(sut.theme.foreground, .red)
        XCTAssertEqual(sut.theme.buttonForeground, .red)
    }

    func testConfigurationForPresentation_whenDefaultOutlineStyleCopied_shouldKeepDefaultOutlineStyle() {
        let sut = SentryUserFeedbackConfiguration()

        let result = sut.configurationForPresentation { config in
            config.configureTheme = { theme in
                theme.background = .blue
            }
        }

        XCTAssertTrue(result.theme.usesDefaultOutlineStyle)
        XCTAssertIdentical(result.theme.outlineStyle, result.theme.defaultOutlineStyle)
    }

    func testConfigurationForPresentation_whenDefaultOutlineStyleValuesChanged_shouldPreserveValuesAndDefaultIdentity() {
        let sut = SentryUserFeedbackConfiguration()
        sut.theme.outlineStyle.color = .red
        sut.theme.outlineStyle.cornerRadius = 9
        sut.theme.outlineStyle.outlineWidth = 2

        let result = sut.configurationForPresentation { config in
            config.tags = ["source": "local"]
        }

        XCTAssertTrue(result.theme.usesDefaultOutlineStyle)
        XCTAssertIdentical(result.theme.outlineStyle, result.theme.defaultOutlineStyle)
        XCTAssertEqual(result.theme.outlineStyle.color, .red)
        XCTAssertEqual(result.theme.outlineStyle.cornerRadius, 9)
        XCTAssertEqual(result.theme.outlineStyle.outlineWidth, 2)
    }

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testConfigurationForPresentation_whenGlobalOnlyFieldsAreSet_shouldIgnoreThem() {
        let button = UIButton()
        let sut = SentryUserFeedbackConfiguration()

        let result = sut.configurationForPresentation { config in
            config.useShakeGesture = true
            config.showFormForScreenshots = true
            config.customButton = button
            config.configureWidget = { widget in
                widget.autoInject = false
            }
        }

        XCTAssertFalse(result.useShakeGesture)
        XCTAssertFalse(result.showFormForScreenshots)
        XCTAssertNil(result.customButton)
        XCTAssertNil(result.configureWidget)
        XCTAssertTrue(result.widgetConfig.autoInject)
    }

    func testConfigurationForPresentation_whenBuildersAppendValues_shouldNotReapplyGlobalBuilders() {
        let sut = SentryUserFeedbackConfiguration()
        var globalConfigureFormCalls = 0
        var localConfigureFormCalls = 0
        sut.configureForm = { form in
            globalConfigureFormCalls += 1
            form.formTitle += " global"
        }
        sut.applyConfigurationBuilders()

        let result = sut.configurationForPresentation { config in
            config.configureForm = { form in
                localConfigureFormCalls += 1
                form.formTitle += " local"
            }
        }

        XCTAssertEqual(globalConfigureFormCalls, 1)
        XCTAssertEqual(localConfigureFormCalls, 1)
        XCTAssertEqual(result.formConfig.formTitle, "Report a Bug global local")
        XCTAssertEqual(sut.formConfig.formTitle, "Report a Bug global")
    }
}

#endif
