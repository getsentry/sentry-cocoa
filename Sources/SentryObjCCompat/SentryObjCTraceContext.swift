// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
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
}

// swiftlint:enable missing_docs
