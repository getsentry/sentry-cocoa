// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalScreenApi) public final class SentryObjCInternalScreenApi: NSObject {
    internal let wrapped: SentryInternalScreenApi

    internal init(_ wrapped: SentryInternalScreenApi) {
        self.wrapped = wrapped
    }

    @objc public func setCurrent(_ screenName: String?) {
        wrapped.setCurrent(screenName)
    }
}

#endif
// swiftlint:enable missing_docs
