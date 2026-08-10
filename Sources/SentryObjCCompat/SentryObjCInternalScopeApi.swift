// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalScopeApi) public final class SentryObjCInternalScopeApi: NSObject {
    private let wrapped: Box<SentryInternalScopeApi>

    internal init(_ wrapped: SentryInternalScopeApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func serializedContexts() -> [String: [String: Any]] {
        wrapped.value.serializedContexts()
    }
}
// swiftlint:enable missing_docs
