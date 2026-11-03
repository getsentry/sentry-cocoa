internal import _SentryPrivate

/// The trace the SDK propagates to downstream services, such as outgoing HTTP requests or
/// web content in a WebView.
struct SentryOutgoingTrace {
    let traceHeader: TraceHeader
    let baggage: Baggage?
    /// `true` when the trace comes from the span bound to the scope, `false` when it comes from
    /// the scope's propagation context because no span is active.
    let isFromSpan: Bool

    /// Returns the span bound to the scope if it belongs to a tracer, otherwise the scope's
    /// propagation context.
    static func current(scope: Scope, options: Options) -> SentryOutgoingTrace {
        if let span = scope.span, let tracer = SentryTracer.getTracer(span) {
            return SentryOutgoingTrace(
                traceHeader: span.toTraceHeader(),
                baggage: tracer.traceContext?.toBaggage(),
                isFromSpan: true
            )
        }

        let baggage = SentryTraceContextSwiftHelper.baggage(
            traceId: scope.propagationContextTraceId.sentryIdString,
            options: options,
            replayId: scope.replayId
        )
        return SentryOutgoingTrace(
            traceHeader: scope.propagationContextTraceHeader,
            baggage: baggage,
            isFromSpan: false
        )
    }
}
