// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCUserFeedbackFormController) public final class SentryObjCUserFeedbackFormController: NSObject {
    @available(iOSApplicationExtension, unavailable)
    @objc public static func viewController() -> UIViewController {
        SentryUserFeedbackFormController()
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(viewControllerWithScreenshot:)
    public static func viewController(screenshot: UIImage?) -> UIViewController {
        SentryUserFeedbackFormController(screenshot: screenshot)
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(viewControllerWithConfigure:)
    public static func viewController(configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?) -> UIViewController {
        SentryUserFeedbackFormController(configure: wrappedConfigure(configure))
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(viewControllerWithScreenshot:configure:)
    public static func viewController(
        screenshot: UIImage?,
        configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?
    ) -> UIViewController {
        SentryUserFeedbackFormController(screenshot: screenshot, configure: wrappedConfigure(configure))
    }

    private static func wrappedConfigure(
        _ configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?
    ) -> SentryUserFeedbackConfigurationCallback? {
        guard let configure = configure else { return nil }
        return { configuration in
            configure(SentryObjCUserFeedbackConfiguration(configuration))
        }
    }
}
#endif

// swiftlint:enable missing_docs
