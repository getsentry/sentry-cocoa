@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryPropagationContext: NSObject {
    @objc public let traceId: SentryId
    let spanId: SpanId
    @objc public var traceHeader: TraceHeader {
        TraceHeader(trace: traceId, spanId: spanId, sampled: .no)
    }
    
    @objc public override init() {
        self.traceId = SentryId()
        self.spanId = SpanId()
    }

    @objc public init(traceId: SentryId, spanId: SpanId) {
        self.traceId = traceId
        self.spanId = spanId
    }
    
    @objc public func traceContextForEvent() -> [String: String] {
        [
            "span_id": spanId.sentrySpanIdString,
            "trace_id": traceId.sentryIdString
        ]
    }
}
