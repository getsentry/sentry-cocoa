@_implementationOnly import Sentry
import Foundation

/// Concrete `@objc` wrapper around the underlying `Sentry.Span` protocol.
///
/// The SDK exposes spans/transactions through a protocol. To keep
/// `@_implementationOnly` viable, this wrapper hides the protocol existential
/// and re-exposes every public member as a class method/property.
@objc(SOCSentrySpan)
public final class Span: NSObject {
    internal let wrapped: any Sentry.Span

    internal init(_ wrapped: any Sentry.Span) {
        self.wrapped = wrapped
        super.init()
    }

    // MARK: - Identity

    @objc public var traceId: SentryId {
        get { SentryId(wrapped.traceId) }
        set { wrapped.traceId = newValue.wrapped }
    }

    @objc public var spanId: SpanId {
        get { SpanId(wrapped.spanId) }
        set { wrapped.spanId = newValue.wrapped }
    }

    @objc public var parentSpanId: SpanId? {
        get { wrapped.parentSpanId.map(SpanId.init) }
        set { wrapped.parentSpanId = newValue?.wrapped }
    }

    @objc public var sampled: SentrySampleDecision {
        get { SentrySampleDecision(wrapped.sampled) }
        set { wrapped.sampled = newValue.underlying }
    }

    @objc public var operation: String {
        get { wrapped.operation }
        set { wrapped.operation = newValue }
    }

    @objc public var origin: String {
        get { wrapped.origin }
        set { wrapped.origin = newValue }
    }

    @objc public var spanDescription: String? {
        get { wrapped.spanDescription }
        set { wrapped.spanDescription = newValue }
    }

    @objc public var status: SentrySpanStatus {
        get { SentrySpanStatus(wrapped.status) }
        set { wrapped.status = newValue.underlying }
    }

    @objc public var timestamp: Date? {
        get { wrapped.timestamp }
        set { wrapped.timestamp = newValue }
    }

    @objc public var startTimestamp: Date? {
        get { wrapped.startTimestamp }
        set { wrapped.startTimestamp = newValue }
    }

    @objc public var data: [String: Any] { wrapped.data }
    @objc public var tags: [String: String] { wrapped.tags }
    @objc public var isFinished: Bool { wrapped.isFinished }

    @objc public var traceContext: TraceContext? {
        wrapped.traceContext.map(TraceContext.init)
    }

    // MARK: - Child spans

    @objc(startChildWithOperation:)
    public func startChild(operation: String) -> Span {
        Span(wrapped.startChild(operation: operation))
    }

    @objc(startChildWithOperation:description:)
    public func startChild(operation: String, description: String?) -> Span {
        Span(wrapped.startChild(operation: operation, description: description))
    }

    // MARK: - Data & tag manipulation

    @objc(setDataValue:forKey:)
    public func setData(value: Any?, key: String) {
        wrapped.setData(value: value, key: key)
    }

    @objc(removeDataForKey:)
    public func removeData(key: String) {
        wrapped.removeData(key: key)
    }

    @objc(setTagValue:forKey:)
    public func setTag(value: String, key: String) {
        wrapped.setTag(value: value, key: key)
    }

    @objc(removeTagForKey:)
    public func removeTag(key: String) {
        wrapped.removeTag(key: key)
    }

    // MARK: - Measurements

    @objc(setMeasurement:value:)
    public func setMeasurement(name: String, value: NSNumber) {
        wrapped.setMeasurement(name: name, value: value)
    }

    // TODO: wrap when SentryMeasurementUnit is wrapped:
    //   setMeasurement(name:value:unit:)

    // MARK: - Finishing

    @objc public func finish() {
        wrapped.finish()
    }

    @objc(finishWithStatus:)
    public func finish(status: SentrySpanStatus) {
        wrapped.finish(status: status.underlying)
    }

    // MARK: - Propagation

    @objc public func toTraceHeader() -> TraceHeader {
        TraceHeader(wrapped.toTraceHeader())
    }

    @objc public func baggageHttpHeader() -> String? {
        wrapped.baggageHttpHeader()
    }
}
