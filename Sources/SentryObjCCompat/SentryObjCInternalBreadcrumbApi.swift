// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalBreadcrumbApi) public final class SentryObjCInternalBreadcrumbApi: NSObject {
    internal let wrapped: SentryInternalBreadcrumbApi

    internal init(_ wrapped: SentryInternalBreadcrumbApi) {
        self.wrapped = wrapped
    }

    @objc public func fromDictionary(_ dictionary: [String: Any]) -> SentryObjCBreadcrumb {
        SentryObjCBreadcrumb(wrapped.fromDictionary(dictionary))
    }
}
// swiftlint:enable missing_docs
