// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCExperimentalOptions) public final class SentryObjCExperimentalOptions: NSObject {
    internal let wrapped: SentryExperimentalOptions

    internal init(_ wrapped: SentryExperimentalOptions) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryExperimentalOptions()
    }

    @objc public var enableUnhandledCPPExceptionsV2: Bool {
        get { wrapped.enableUnhandledCPPExceptionsV2 }
        set { wrapped.enableUnhandledCPPExceptionsV2 = newValue }
    }

    #if !SDK_V10
    @objc public var enableWatchdogTerminationsV2: Bool {
        get { wrapped.enableWatchdogTerminationsV2 }
        @available(*, deprecated, message: "enableWatchdogTerminationsV2 is deprecated and will be removed in v10, where the improved watchdog termination tracking mechanism is enabled by default.")
        set { wrapped.enableWatchdogTerminationsV2 = newValue }
    }
    #endif

    @objc public var enableUIViewControllerInitSwizzling: Bool {
        get { wrapped.enableUIViewControllerInitSwizzling }
        set { wrapped.enableUIViewControllerInitSwizzling = newValue }
    }
}

// swiftlint:enable missing_docs
