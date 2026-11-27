// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCInternalBreadcrumbApi) public final class SentryObjCInternalBreadcrumbApi: NSObject {
    internal let wrapped: Box<SentryInternalBreadcrumbApi>

    internal init(_ wrapped: SentryInternalBreadcrumbApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func fromDictionary(_ dictionary: [String: Any]) -> SentryObjCBreadcrumb {
        SentryObjCBreadcrumb(wrapped.value.fromDictionary(dictionary))
    }
}
// swiftlint:enable missing_docs
