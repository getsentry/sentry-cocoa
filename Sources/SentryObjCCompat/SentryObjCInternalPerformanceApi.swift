// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalPerformanceApi) public final class SentryObjCInternalPerformanceApi: NSObject {
    internal let wrapped: SentryInternalPerformanceApi

    internal init(_ wrapped: SentryInternalPerformanceApi) {
        self.wrapped = wrapped
    }

    @objc public var framesTrackingHybridSDKMode: Bool {
        get { wrapped.framesTrackingHybridSDKMode }
        set { wrapped.framesTrackingHybridSDKMode = newValue }
    }

    @objc public var isFramesTrackingRunning: Bool {
        wrapped.isFramesTrackingRunning
    }
}

#endif
// swiftlint:enable missing_docs
