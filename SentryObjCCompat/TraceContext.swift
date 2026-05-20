@_implementationOnly import Sentry
import Foundation

/// Trace-level context propagated in the baggage header.
@objc(SOCSentryTraceContext)
public final class TraceContext: NSObject {
    internal let wrapped: Sentry.TraceContext

    internal init(_ wrapped: Sentry.TraceContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public var traceId: SentryId { SentryId(wrapped.traceId) }
    @objc public var publicKey: String { wrapped.publicKey }
    @objc public var releaseName: String? { wrapped.releaseName }
    @objc public var environment: String? { wrapped.environment }
    @objc public var transaction: String? { wrapped.transaction }
    @objc public var sampleRate: String? { wrapped.sampleRate }
    @objc public var sampleRand: String? { wrapped.sampleRand }
    @objc public var sampled: String? { wrapped.sampled }
    @objc public var replayId: String? { wrapped.replayId }
    @objc public var orgId: String? { wrapped.orgId }
}
