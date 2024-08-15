import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension 13.0, *)
@objc public class SentryUserFeedbackConfiguration: NSObject {
    
    /**
     * Configuration settings specific to the managed widget that displays the UI form.
     * - note: Default: `nil`
     */
    public var widget: ((SentryUserFeedbackWidgetConfiguration) -> Void)?
    
    /**
     * Configuration settings specific to the managed UI form to gather user input.
     * - note: Default: `nil`
     */
    public var uiForm: ((SentryUserFeedbackFormConfiguration) -> Void)?

    /**
     * Tags to set on the feedback event. This is a dictionary where keys are strings
     * and values can be different data types such as `NSNumber`, `NSString`, etc.
     * - note: Default: `nil`
     */
    public var tags: [String: Any]?
    
    /**
     * Sets the email and name field text content to `SentryUser.email` and `SentryUser.name`.
     * - note: Default: `false`
     */
    public var useSentryUser: Bool = false
    
    /**
     * Called when the feedback form is opened.
     * - note: Default: `nil`
     */
    public var onFormOpen: (() -> Void)?
    
    /**
     * Called when the feedback form is closed.
     * - note: Default: `nil`
     */
    public var onFormClose: (() -> Void)?
    
    /**
     * Called when feedback is successfully submitted.
     * The data dictionary contains the feedback details.
     * - note: Default: `nil`
     */
    public var onSubmitSuccess: (([String: Any]) -> Void)?
    
    /**
     * Called when there is an error submitting feedback.
     * The error object contains details of the error.
     * - note: Default: `nil`
     */
    public var onSubmitError: ((Error) -> Void)?
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
