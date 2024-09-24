import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The default method to show the feedback form is via a floating widget placed in the bottom trailing corner of the screen. See the configuration classes for alternative options.
 */
@objcMembers public class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private var widgetConfig: SentryUserFeedbackWidgetConfiguration?
    private var formConfig: SentryUserFeedbackFormConfiguration?
    private var themeOverrides: SentryUserFeedbackThemeConfiguration?
    private var darkThemeOverrides: SentryUserFeedbackThemeConfiguration?
    private var window: SentryWidget.Window?
    
    public init(configuration: SentryUserFeedbackConfiguration) {
        self.configuration = configuration
        super.init()
        
        if let widgetConfigBuilder = configuration.configureWidget {
            let config = SentryUserFeedbackWidgetConfiguration()
            widgetConfigBuilder(config)
            validate(config)
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
        guard let config = widgetConfig else {
            SentryLog.warning("Cannot create a user feedback widget without a configuration.")
            return
        }
        window = SentryWidget.Window(config: config)
        window?.isHidden = false
    }
    
    /**
     * Removes the feedback widget from the view hierarchy. Useful for cleanup when the widget is no longer needed.
     */
    func removeWidget() {
        // TODO: Implementation to remove widget from view hierarchy
    }
    
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
    
    private func validate(_ config: SentryUserFeedbackWidgetConfiguration) {
        let noOpposingHorizontals = config.location.contains(.right) && !config.location.contains(.left)
            || !config.location.contains(.right) && config.location.contains(.left)
        let noOpposingVerticals = config.location.contains(.top) && !config.location.contains(.bottom)
            || !config.location.contains(.top) && config.location.contains(.bottom)
        let atLeastOneLocation = config.location.contains(.right)
            || config.location.contains(.left)
            || config.location.contains(.top)
            || config.location.contains(.bottom)
        let notAll = !config.location.contains(.all)
        let valid = noOpposingVerticals && noOpposingHorizontals && atLeastOneLocation && notAll
        #if DEBUG
        assert(valid, "Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
        #endif // DEBUG
        if !valid {
            SentryLog.warning("Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
