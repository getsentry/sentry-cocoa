// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCInternalAppStartApi) public final class SentryObjCInternalAppStartApi: NSObject {
    private let wrapped: Box<SentryInternalAppStartApi>

    internal init(_ wrapped: SentryInternalAppStartApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var hybridSDKMode: Bool {
        get { wrapped.value.hybridSDKMode }
        set { wrapped.value.hybridSDKMode = newValue }
    }

    @objc public var measurementWithSpans: [String: Any]? {
        wrapped.value.measurementWithSpans
    }
}
// swiftlint:enable missing_docs
