// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalScreenApi) public final class SentryObjCInternalScreenApi: NSObject {
    internal let wrapped: Box<SentryInternalScreenApi>

    internal init(_ wrapped: SentryInternalScreenApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func setCurrent(_ screenName: String?) {
        wrapped.value.setCurrent(screenName)
    }
}

#endif
// swiftlint:enable missing_docs
