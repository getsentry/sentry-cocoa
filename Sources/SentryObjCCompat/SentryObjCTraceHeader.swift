// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCTraceHeader) public final class SentryObjCTraceHeader: NSObject {
    internal let wrapped: TraceHeader

    internal init(_ wrapped: TraceHeader) {
        self.wrapped = wrapped
    }

    @objc public init(traceId: SentryObjCId, spanId: SentryObjCSpanId, sampled: SentryObjCSampleDecision) {
        self.wrapped = TraceHeader(trace: traceId.wrapped, spanId: spanId.wrapped, sampled: sampled.underlying)
    }

    @objc public var traceId: SentryObjCId {
        SentryObjCId(wrapped.traceId)
    }

    @objc public var spanId: SentryObjCSpanId {
        SentryObjCSpanId(wrapped.spanId)
    }

    @objc public var sampled: SentryObjCSampleDecision {
        SentryObjCSampleDecision(wrapped.sampled)
    }

    @objc public func value() -> String {
        wrapped.value()
    }
}

// swiftlint:enable missing_docs
