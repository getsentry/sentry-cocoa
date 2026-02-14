protocol TelemetryItem: Encodable {
    var attributesDict: [String: SentryAttributeContent] { get set }
    var traceId: SentryId { get set }
    var spanId: SpanId? { get set }
}
