import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The default method to show the feedback form is via a floating widget placed in the bottom trailing corner of the screen. See the configuration classes for alternative options.
 */
@available(iOS 13.0, *)
@objcMembers
class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private var window: SentryUserFeedbackWidget.Window?
    
    public init(configuration: SentryUserFeedbackConfiguration) {
        self.configuration = configuration
        super.init()
        
        if let widgetConfigBuilder = configuration.configureWidget {
            widgetConfigBuilder(configuration.widgetConfig)
            validate(configuration.widgetConfig)
        }
        if let uiFormConfigBuilder = configuration.configureForm {
            uiFormConfigBuilder(configuration.formConfig)
        }
        if let themeOverrideBuilder = configuration.configureTheme {
            themeOverrideBuilder(configuration.theme)
        }
        if let darkThemeOverrideBuilder = configuration.configureDarkTheme {
            darkThemeOverrideBuilder(configuration.darkTheme)
        }
        
        if configuration.widgetConfig.autoInject {
            createWidget()
        }
    }

    /**
     * Attaches the feedback widget to a specified UIButton. The button will trigger the feedback form.
     * - Parameter button: The UIButton to attach the widget to.
     */
    func attachToButton(_ button: UIButton) {
        
    }
    
    /**
     * Creates and renders the feedback widget on the screen.
     * If `SentryUserFeedbackConfiguration.autoInject` is `false`, this must be called explicitly.
     */
    func createWidget() {
        window = SentryUserFeedbackWidget.Window(config: configuration)
        window?.isHidden = false
    }
    
    /**
     * Removes the feedback widget from the view hierarchy. Useful for cleanup when the widget is no longer needed.
     */
    func removeWidget() {
        
    }
    
    private func validate(_ config: SentryUserFeedbackWidgetConfiguration) {
        let noOpposingHorizontals = config.location.contains(.trailing) && !config.location.contains(.leading)
            || !config.location.contains(.trailing) && config.location.contains(.leading)
        let noOpposingVerticals = config.location.contains(.top) && !config.location.contains(.bottom)
            || !config.location.contains(.top) && config.location.contains(.bottom)
        let atLeastOneLocation = config.location.contains(.trailing)
            || config.location.contains(.leading)
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

#endif // os(iOS) && !SENTRY_NO_UIKIT
