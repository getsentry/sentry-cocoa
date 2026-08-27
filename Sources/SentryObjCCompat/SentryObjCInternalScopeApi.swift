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

    @objc public func withCurrentScope(_ scope: SentryObjCScope, callback: () -> Void) {
        wrapped.value.withCurrentScope(scope.wrapped, callback)
    }

    @objc public func createScope() -> SentryObjCScope {
        SentryObjCScope(wrapped.value.createScope())
    }

    @objc public func cloneScope(_ scope: SentryObjCScope) -> SentryObjCScope {
        SentryObjCScope(wrapped.value.cloneScope(scope.wrapped))
    }
}
// swiftlint:enable missing_docs
