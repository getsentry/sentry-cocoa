// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalUserApi) public final class SentryObjCInternalUserApi: NSObject {
    internal let wrapped: Box<SentryInternalUserApi>

    internal init(_ wrapped: SentryInternalUserApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func fromDictionary(_ dictionary: [String: Any]) -> SentryObjCUser {
        SentryObjCUser(wrapped.value.fromDictionary(dictionary))
    }
}
// swiftlint:enable missing_docs
