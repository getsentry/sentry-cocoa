internal import SentrySwift
import Foundation

/// W3C-style `sentry-trace` HTTP header.
@objc(SOCSentryTraceHeader)
public final class TraceHeader: NSObject {
    internal let wrapped: SentrySwift.TraceHeader

    internal init(_ wrapped: SentrySwift.TraceHeader) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(traceId: SentryId, spanId: SpanId, sampled: SentrySampleDecision) {
        self.wrapped = SentrySwift.TraceHeader(
            trace: traceId.wrapped,
            spanId: spanId.wrapped,
            sampled: sampled.underlying
        )
        super.init()
    }

    @objc public var traceId: SentryId { SentryId(wrapped.traceId) }
    @objc public var spanId: SpanId { SpanId(wrapped.spanId) }
    @objc public var sampled: SentrySampleDecision { SentrySampleDecision(wrapped.sampled) }

    /// Value to use in the `sentry-trace` HTTP header.
    @objc public func value() -> String { wrapped.value() }
}
