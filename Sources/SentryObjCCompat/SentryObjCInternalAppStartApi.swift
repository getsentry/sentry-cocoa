// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalAppStartApi) public final class SentryObjCInternalAppStartApi: NSObject {
    internal let wrapped: SentryInternalAppStartApi

    internal init(_ wrapped: SentryInternalAppStartApi) {
        self.wrapped = wrapped
    }

    @objc public var hybridSDKMode: Bool {
        get { wrapped.hybridSDKMode }
        set { wrapped.hybridSDKMode = newValue }
    }

    @objc public var measurementWithSpans: [String: Any]? {
        wrapped.measurementWithSpans
    }
}
// swiftlint:enable missing_docs
