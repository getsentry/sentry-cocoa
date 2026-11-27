// swiftlint:disable missing_docs
internal import Sentry
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))

@objc(SentryObjCInternalViewHierarchyApi) public final class SentryObjCInternalViewHierarchyApi: NSObject {
    internal let wrapped: Box<SentryInternalViewHierarchyApi>

    internal init(_ wrapped: SentryInternalViewHierarchyApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func capture() -> Data? {
        wrapped.value.capture()
    }
}

#endif
// swiftlint:enable missing_docs
