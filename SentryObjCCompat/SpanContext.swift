internal import SentrySwift
import Foundation

/// Read-only context describing a span's identity.
@objc(SOCSentrySpanContext)
public class SpanContext: NSObject {
    internal let wrapped: SentrySwift.SpanContext

    internal init(_ wrapped: SentrySwift.SpanContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(operation: String) {
        self.wrapped = SentrySwift.SpanContext(operation: operation)
        super.init()
    }

    @objc public init(operation: String, sampled: SentrySampleDecision) {
        self.wrapped = SentrySwift.SpanContext(operation: operation, sampled: sampled.underlying)
        super.init()
    }

    @objc public init(
        traceId: SentryId,
        spanId: SpanId,
        parentId: SpanId?,
        operation: String,
        sampled: SentrySampleDecision
    ) {
        self.wrapped = SentrySwift.SpanContext(
            trace: traceId.wrapped,
            spanId: spanId.wrapped,
            parentId: parentId?.wrapped,
            operation: operation,
            sampled: sampled.underlying
        )
        super.init()
    }

    @objc public init(
        traceId: SentryId,
        spanId: SpanId,
        parentId: SpanId?,
        operation: String,
        spanDescription: String?,
        sampled: SentrySampleDecision
    ) {
        self.wrapped = SentrySwift.SpanContext(
            trace: traceId.wrapped,
            spanId: spanId.wrapped,
            parentId: parentId?.wrapped,
            operation: operation,
            spanDescription: spanDescription,
            sampled: sampled.underlying
        )
        super.init()
    }

    @objc public var traceId: SentryId { SentryId(wrapped.traceId) }
    @objc public var spanId: SpanId { SpanId(wrapped.spanId) }
    @objc public var parentSpanId: SpanId? { wrapped.parentSpanId.map(SpanId.init) }
    @objc public var sampled: SentrySampleDecision { SentrySampleDecision(wrapped.sampled) }
    @objc public var operation: String { wrapped.operation }
    @objc public var spanDescription: String? { wrapped.spanDescription }

    @objc public var origin: String {
        get { wrapped.origin }
        set { wrapped.origin = newValue }
    }
}
