// swiftlint:disable missing_docs
internal import Sentry
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))

@objc(SentryObjCInternalScreenshotApi) public final class SentryObjCInternalScreenshotApi: NSObject {
    internal let wrapped: Box<SentryInternalScreenshotApi>

    internal init(_ wrapped: SentryInternalScreenshotApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func capture() -> [Data]? {
        wrapped.value.capture()
    }
}

#endif
// swiftlint:enable missing_docs
