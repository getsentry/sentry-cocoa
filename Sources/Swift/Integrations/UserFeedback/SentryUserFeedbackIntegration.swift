import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The default method to show the feedback form is via a floating widget placed in the bottom trailing corner of the screen. See the configuration classes for alternative options.
 */
class SentryUserFeedbackIntegration {
    let configuration: SentryUserFeedbackConfiguration
    private var widgetConfig: SentryUserFeedbackWidgetConfiguration?
    private var formConfig: SentryUserFeedbackFormConfiguration?
    private var themeOverrides: SentryUserFeedbackThemeConfiguration?
    private var darkThemeOverrides: SentryUserFeedbackThemeConfiguration?
    
    init(configuration: SentryUserFeedbackConfiguration) {
        self.configuration = configuration
        
        if let widgetConfigBuilder = configuration.configureWidget {
            let config = SentryUserFeedbackWidgetConfiguration()
            widgetConfigBuilder(config)
            self.widgetConfig = config
        }
        if let uiFormConfigBuilder = configuration.configureForm {
            let config = SentryUserFeedbackFormConfiguration()
            uiFormConfigBuilder(config)
            self.formConfig = config
            
            if let themeOverrideBuilder = config.themeOverrides {
                let overrides = SentryUserFeedbackThemeConfiguration()
                themeOverrideBuilder(overrides)
                self.themeOverrides = overrides
            }
            if let darkThemeOverrideBuilder = config.darkThemeOverrides {
                let overrides = SentryUserFeedbackThemeConfiguration()
                darkThemeOverrideBuilder(overrides)
                self.darkThemeOverrides = overrides
            }
        }
        
        if widgetConfig?.autoInject ?? false {
            createWidget()
        }
    }
    
// swiftlint:disable todo
    
    /**
     * Attaches the feedback widget to a specified UIButton. The button will trigger the feedback form.
     * - Parameter button: The UIButton to attach the widget to.
     */
    func attachToButton(_ button: UIButton) {
        // TODO: Implementation to attach widget to button
    }
    
    /**
     * Creates and renders the feedback widget on the screen.
     * If `SentryUserFeedbackConfiguration.autoInject` is `false`, this must be called explicitly.
     */
    func createWidget() {
        // TODO: Implementation to create and render widget
    }
    
    /**
     * Removes the feedback widget from the view hierarchy. Useful for cleanup when the widget is no longer needed.
     */
    func removeWidget() {
        // TODO: Implementation to remove widget from view hierarchy
    }
    
// swiftlint:enable todo
    
    /**
     * Captures feedback using custom UI. This method allows you to submit feedback data directly.
     * - Parameters:
     *   - message: The feedback message (required).
     *   - name: The name of the user (optional).
     *   - email: The email of the user (optional).
     *   - hints: Additional hints or metadata for the feedback submission (optional).
     */
    func captureFeedback(message: String, name: String? = nil, email: String? = nil, hints: [String: Any]? = nil) {
        // Implementation to capture feedback
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
