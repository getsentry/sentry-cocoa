// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    private let wrapped: SentryInternalApi

    internal init(_ wrapped: SentryInternalApi) {
        self.wrapped = wrapped
    }

    @objc public var sdk: SentryObjCInternalSdkApi {
        SentryObjCInternalSdkApi(wrapped.sdk)
    }
}
// swiftlint:enable missing_docs
