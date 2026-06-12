// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalUserApi) public final class SentryObjCInternalUserApi: NSObject {
    internal let wrapped: SentryInternalUserApi

    internal init(_ wrapped: SentryInternalUserApi) {
        self.wrapped = wrapped
    }

    @objc public func fromDictionary(_ dictionary: [String: Any]) -> SentryObjCUser {
        SentryObjCUser(wrapped.fromDictionary(dictionary))
    }
}
// swiftlint:enable missing_docs
