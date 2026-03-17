// swiftlint:disable missing_docs
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

    /// Determines whether a trace should be continued based on the incoming baggage org ID
    /// and the SDK options.
    ///
    /// Decision matrix:
    /// | Baggage org | SDK org | strict=false | strict=true |
    /// |-------------|---------|-------------|-------------|
    /// | 1           | 1       | Continue    | Continue    |
    /// | None        | 1       | Continue    | New trace   |
    /// | 1           | None    | Continue    | New trace   |
    /// | None        | None    | Continue    | Continue    |
    /// | 1           | 2       | New trace   | New trace   |
    @objc public static func shouldContinueTrace(
        options: Options,
        baggageOrgId: String?
    ) -> Bool {
        let sdkOrgId = options.effectiveOrgId

        // Mismatched org IDs always reject regardless of strict mode
        if let sdkOrgId = sdkOrgId,
           let baggageOrgId = baggageOrgId,
           sdkOrgId != baggageOrgId {
            SentrySDKLog.debug(
                "Won't continue trace because org IDs don't match "
                    + "(incoming baggage: \(baggageOrgId), SDK options: \(sdkOrgId))"
            )
            return false
        }

        if options.strictTraceContinuation {
            // With strict continuation both must be present and match,
            // unless both are missing
            if sdkOrgId == nil && baggageOrgId == nil {
                return true
            }
            if sdkOrgId == nil || baggageOrgId == nil {
                SentrySDKLog.debug(
                    "Starting new trace because strict trace continuation is enabled "
                        + "but one org ID is missing (incoming baggage: "
                        + "\(baggageOrgId ?? "nil"), SDK: \(sdkOrgId ?? "nil"))"
                )
                return false
            }
        }

        return true
    }
}
// swiftlint:enable missing_docs
