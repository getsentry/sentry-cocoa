// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCUserFeedbackConfiguration) public final class SentryObjCUserFeedbackConfiguration: NSObject {
    internal let wrapped: SentryUserFeedbackConfiguration

    internal init(_ wrapped: SentryUserFeedbackConfiguration) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryUserFeedbackConfiguration()
    }

    @objc public var animations: Bool {
        get { wrapped.animations }
        set { wrapped.animations = newValue }
    }

    @objc public var useShakeGesture: Bool {
        get { wrapped.useShakeGesture }
        set { wrapped.useShakeGesture = newValue }
    }

    @objc public var showFormForScreenshots: Bool {
        get { wrapped.showFormForScreenshots }
        set { wrapped.showFormForScreenshots = newValue }
    }

    @objc public var customButton: UIButton? {
        get { wrapped.customButton }
        set { wrapped.customButton = newValue }
    }

    @objc public var configureForm: ((SentryObjCUserFeedbackFormConfiguration) -> Void)? {
        get {
            guard let configureForm = wrapped.configureForm else { return nil }
            return { configuration in
                configureForm(configuration.wrapped)
            }
        }
        set {
            if let configureForm = newValue {
                wrapped.configureForm = { configuration in
                    configureForm(SentryObjCUserFeedbackFormConfiguration(configuration))
                }
            } else {
                wrapped.configureForm = nil
            }
        }
    }

    @objc public var tags: [String: Any]? {
        get { wrapped.tags }
        set { wrapped.tags = newValue }
    }

    @objc public var onFormOpen: (() -> Void)? {
        get { wrapped.onFormOpen }
        set { wrapped.onFormOpen = newValue }
    }

    @objc public var onFormClose: (() -> Void)? {
        get { wrapped.onFormClose }
        set { wrapped.onFormClose = newValue }
    }

    @objc public var onSubmitSuccess: (([String: Any]) -> Void)? {
        get { wrapped.onSubmitSuccess }
        set { wrapped.onSubmitSuccess = newValue }
    }

    @objc public var onSubmitError: ((NSError) -> Void)? {
        get {
            guard let onSubmitError = wrapped.onSubmitError else { return nil }
            return { error in
                onSubmitError(error)
            }
        }
        set {
            if let onSubmitError = newValue {
                wrapped.onSubmitError = { error in
                    onSubmitError(error as NSError)
                }
            } else {
                wrapped.onSubmitError = nil
            }
        }
    }

    @objc public var configureTheme: ((SentryObjCUserFeedbackThemeConfiguration) -> Void)? {
        get {
            guard let configureTheme = wrapped.configureTheme else { return nil }
            return { configuration in
                configureTheme(configuration.wrapped)
            }
        }
        set {
            if let configureTheme = newValue {
                wrapped.configureTheme = { configuration in
                    configureTheme(SentryObjCUserFeedbackThemeConfiguration(configuration))
                }
            } else {
                wrapped.configureTheme = nil
            }
        }
    }
}
#endif

// swiftlint:enable missing_docs
