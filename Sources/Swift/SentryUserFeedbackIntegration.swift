import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension 13.0, *)
class SentryUserFeedbackIntegration {
    let configuration: SentryUserFeedbackConfiguration
    
    init(configuration: SentryUserFeedbackConfiguration) {
        self.configuration = configuration
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
        // TODO: Implementation to create and render widget
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
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
