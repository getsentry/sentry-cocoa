// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
@_implementationOnly import _SentryPrivate
import Foundation

@objc(SentryObjCTraceContext) public final class SentryObjCTraceContext: NSObject {
    internal let wrapped: TraceContext

    internal init(_ wrapped: TraceContext) {
        self.wrapped = wrapped
    }

    @objc public var traceId: SentryObjCId {
        SentryObjCId(wrapped.traceId)
    }

    @objc public var publicKey: String {
        wrapped.publicKey
    }

    @objc public var releaseName: String? {
        wrapped.releaseName
    }

    @objc public var environment: String? {
        wrapped.environment
    }

    @objc public var transaction: String? {
        wrapped.transaction
    }

    @objc public var sampleRate: String? {
        wrapped.sampleRate
    }

    @objc public var sampleRand: String? {
        wrapped.sampleRand
    }

    @objc public var sampled: String? {
        wrapped.sampled
    }

    @objc public var replayId: String? {
        wrapped.replayId
    }

    @objc public var orgId: String? {
        wrapped.orgId
    }

    // MARK: - Testing
    
    /// Test-only initializer. Do not use in production code.
    @objc public init?(testDict dict: [String: Any]) {
        guard let wrapped = TraceContext(dict: dict) else { return nil }
        self.wrapped = wrapped
    }

}

// swiftlint:enable missing_docs
