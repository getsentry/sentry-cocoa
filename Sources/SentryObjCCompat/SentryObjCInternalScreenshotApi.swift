// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalScreenshotApi) public final class SentryObjCInternalScreenshotApi: NSObject {
    internal let wrapped: SentryInternalScreenshotApi

    internal init(_ wrapped: SentryInternalScreenshotApi) {
        self.wrapped = wrapped
    }

    @objc public func capture() -> [Data]? {
        wrapped.capture()
    }
}

#endif
// swiftlint:enable missing_docs
