// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalPerformanceApi) public final class SentryObjCInternalPerformanceApi: NSObject {
    internal let wrapped: Box<SentryInternalPerformanceApi>

    internal init(_ wrapped: SentryInternalPerformanceApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var framesTrackingHybridSDKMode: Bool {
        get { wrapped.value.framesTrackingHybridSDKMode }
        set { wrapped.value.framesTrackingHybridSDKMode = newValue }
    }

    @objc public var isFramesTrackingRunning: Bool {
        wrapped.value.isFramesTrackingRunning
    }
}

#endif
// swiftlint:enable missing_docs
