// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public class SentryObjCSpanContext: NSObject {
    internal var wrapped: SpanContext

    internal init(_ wrapped: SpanContext) {
        self.wrapped = wrapped
    }

    @objc public init(operation: String) {
        self.wrapped = SpanContext(operation: operation)
    }

    @objc public init(operation: String, sampled: SentryObjCSampleDecision) {
        self.wrapped = SpanContext(operation: operation, sampled: sampled.underlying)
    }

    @objc public init(traceId: SentryObjCId, spanId: SentryObjCSpanId, parentId: SentryObjCSpanId?, operation: String, sampled: SentryObjCSampleDecision) {
        self.wrapped = SpanContext(trace: traceId.wrapped, spanId: spanId.wrapped, parentId: parentId?.wrapped, operation: operation, sampled: sampled.underlying)
    }

    @objc public init(traceId: SentryObjCId, spanId: SentryObjCSpanId, parentId: SentryObjCSpanId?, operation: String, spanDescription: String?, sampled: SentryObjCSampleDecision) {
        self.wrapped = SpanContext(trace: traceId.wrapped, spanId: spanId.wrapped, parentId: parentId?.wrapped, operation: operation, spanDescription: spanDescription, sampled: sampled.underlying)
    }

    @objc public var traceId: SentryObjCId {
        SentryObjCId(wrapped.traceId)
    }

    @objc public var spanId: SentryObjCSpanId {
        SentryObjCSpanId(wrapped.spanId)
    }

    @objc public var parentSpanId: SentryObjCSpanId? {
        guard let p = wrapped.parentSpanId else { return nil }
        return SentryObjCSpanId(p)
    }

    @objc public var sampled: SentryObjCSampleDecision {
        SentryObjCSampleDecision(wrapped.sampled)
    }

    @objc public var operation: String {
        wrapped.operation
    }

    @objc public var spanDescription: String? {
        wrapped.spanDescription
    }

    @objc public var origin: String {
        get { wrapped.origin }
        set { wrapped.origin = newValue }
    }
}

// swiftlint:enable missing_docs
