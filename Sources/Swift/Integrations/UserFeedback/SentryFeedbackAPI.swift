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

    /// Present the feedback form from the foreground window scene.
    ///
    /// If a SwiftUI feedback form modifier is registered, the SDK presents with SwiftUI sheet presentation.
    /// Otherwise, the SDK presents from the foreground window scene's root view controller.
    ///
    /// - Returns: `true` if presentation was requested, or `false` if feedback isn't configured,
    /// no presenter is available, or the presenter can't currently present.
    /// - warning: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    @objc(presentForm)
    @discardableResult public func presentForm() -> Bool {
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.presentForm()
            }
            return true
        }

        return integration.driver.presentForm()
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
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak viewController] in
                guard let viewController = viewController else { return }
                self?.presentForm(from: viewController)
            }
            return true
        }

        return integration.driver.presentForm(from: viewController)
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
        guard let integration = Self.getIntegration() else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            return false
        }

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak windowScene] in
                guard let windowScene = windowScene else { return }
                self?.presentForm(in: windowScene)
            }
            return true
        }

        return integration.driver.presentForm(in: windowScene)
    }
    
    static func getIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self) as? UserFeedbackIntegration<SentryDependencyContainer>
    }
}

#endif
