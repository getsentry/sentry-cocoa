@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// API for interacting with the feature User Feedback  
@objc public final class SentryFeedbackAPI: NSObject {
    
    /// Show the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func showWidget() {
        Self.getIntegration()?.driver.showWidget()
    }
    
    /// Hide the feedback widget button.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - seealso: See `SentryOptions.configureUserFeedback` to configure the widget.
    @available(iOSApplicationExtension, unavailable)
    @objc public func hideWidget() {
        Self.getIntegration()?.driver.hideWidget()
    }

    /// Present the feedback form using the best available presenter.
    ///
    /// If a SwiftUI feedback form modifier is registered, the SDK presents with SwiftUI sheet presentation.
    /// Otherwise, the SDK presents from the configured custom button host, widget host, foreground
    /// window scene root view controller, or first available key-window root view controller.
    ///
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentForm)
    @discardableResult public func presentForm() -> Bool {
        return presentForm(image: nil)
    }

    /// Present the feedback form using the best available presenter.
    ///
    /// If a SwiftUI feedback form modifier is registered, the SDK presents with SwiftUI sheet presentation.
    /// Otherwise, the SDK presents from the configured custom button host, widget host, foreground
    /// window scene root view controller, or first available key-window root view controller.
    ///
    /// - Parameter image: An optional image to attach to the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentFormWithImage:)
    @discardableResult public func presentForm(image: UIImage? = nil) -> Bool {
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        return integration.driver.presentForm(screenshot: image)
    }

    /// Present the feedback form from a specific view controller.
    ///
    /// - Parameter viewController: The view controller used to present the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured
    /// or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentFormFromViewController:)
    @discardableResult public func presentForm(from viewController: UIViewController) -> Bool {
        return presentForm(from: viewController, image: nil)
    }

    /// Present the feedback form from a specific view controller.
    ///
    /// - Parameters:
    ///   - viewController: The view controller used to present the feedback form.
    ///   - image: An optional image to attach to the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured
    /// or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentFormFromViewController:image:)
    @discardableResult public func presentForm(from viewController: UIViewController, image: UIImage? = nil) -> Bool {
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        return integration.driver.presentForm(from: viewController, screenshot: image)
    }

    /// Present the feedback form in a specific window scene.
    ///
    /// - Parameter windowScene: The window scene used to find a presenter for the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentFormInWindowScene:)
    @discardableResult public func presentForm(in windowScene: UIWindowScene) -> Bool {
        return presentForm(in: windowScene, image: nil)
    }

    /// Present the feedback form in a specific window scene.
    ///
    /// - Parameters:
    ///   - windowScene: The window scene used to find a presenter for the feedback form.
    ///   - image: An optional image to attach to the feedback form.
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentFormInWindowScene:image:)
    @discardableResult public func presentForm(in windowScene: UIWindowScene, image: UIImage? = nil) -> Bool {
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        return integration.driver.presentForm(in: windowScene, screenshot: image)
    }
    
    static func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
