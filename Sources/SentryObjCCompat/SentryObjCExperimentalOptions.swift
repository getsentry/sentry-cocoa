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

    @objc public var enableWatchdogTerminationsV2: Bool {
        get { wrapped.enableWatchdogTerminationsV2 }
        set { wrapped.enableWatchdogTerminationsV2 = newValue }
    }

    @objc public var dataCollection: SentryObjCDataCollectionOptions {
        get { SentryObjCDataCollectionOptions(parent: wrapped) }
        set { wrapped.dataCollection = newValue.wrapped }
    }
}

// swiftlint:enable missing_docs
