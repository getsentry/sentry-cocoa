// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    private let wrapped: Box<SentryInternalApi>

    internal init(_ wrapped: SentryInternalApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var sdk: SentryObjCInternalSdkApi {
        SentryObjCInternalSdkApi(wrapped.value.sdk)
    }
}
// swiftlint:enable missing_docs
