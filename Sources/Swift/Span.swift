internal import _SentryPrivate
import Foundation

// The Xcode target imports this name from SentryDefines.h. SwiftPM's SentryHeaders
// module only forward-declares the span protocol, so the importer drops the typedef.
#if SWIFT_PACKAGE
/// Drops or modifies a span before the SDK sends it. Return `nil` to drop the span.
public typealias SentryBeforeSendSpanCallback = (any Span) -> (any Span)?
#endif

#if SDK_V10
/// A span measuring one unit of work inside a transaction.
@objc(SentrySpan)
public protocol Span: NSObjectProtocol {
    /// Determines which trace the span belongs to.
    var traceId: SentryId { get set }

    /// Span id.
    var spanId: SpanId { get set }

    /// The id of the parent span.
    var parentSpanId: SpanId? { get set }

    /// The sampling decision of the trace.
    var sampled: SentrySampleDecision { get set }

    /// Short code identifying the type of operation the span is measuring.
    var operation: String { get set }

    /// The origin of the span indicates what created the span.
    ///
    /// Gets set by the SDK. Callers are not expected to set it. The protocol allows this value to
    /// be optional, and the SDK still always sends it.
    ///
    /// See https://develop.sentry.dev/sdk/performance/trace-origin
    var origin: String { get set }

    /// Longer description of the span's operation, which uniquely identifies the span but is
    /// consistent across instances of the span.
    var spanDescription: String? { get set }

    /// Describes the status of the transaction.
    var status: SentrySpanStatus { get set }

    /// The timestamp at which the span ended.
    var timestamp: Date? { get set }

    /// The start time of the span.
    var startTimestamp: Date? { get set }

    /// An arbitrary mapping of additional metadata of the span.
    var data: [String: Any] { get }

    /// Key-value pairs holding additional data about the span.
    var tags: [String: String] { get }

    /// Whether the span is finished.
    var isFinished: Bool { get }

    /// Retrieves a trace context from this tracer.
    var traceContext: TraceContext? { get }

    /// Starts a child span.
    /// - Parameter operation: Short code identifying the type of operation the span is measuring.
    @objc(startChildWithOperation:)
    func startChild(operation: String) -> any Span

    /// Starts a child span.
    /// - Parameters:
    ///   - operation: Defines the child span operation.
    ///   - description: Defines the child span description.
    @objc(startChildWithOperation:description:)
    func startChild(operation: String, description: String?) -> any Span

    /// Sets a value in ``data``.
    @objc(setDataValue:forKey:)
    func setData(value: Any?, key: String)

    /// Removes a data value.
    @objc(removeDataForKey:)
    func removeData(key: String)

    /// Sets a tag value.
    @objc(setTagValue:forKey:)
    func setTag(value: String, key: String)

    /// Removes a tag value.
    @objc(removeTagForKey:)
    func removeTag(key: String)

    /// Sets a measurement on this span without a unit.
    ///
    /// No formatting is applied to the measurement value in the Sentry product, and the value is
    /// shown as is. Setting a measurement with the same name on the same span multiple times only
    /// keeps the last value. Child span measurements are not forwarded to the root transaction.
    @objc(setMeasurement:value:)
    func setMeasurement(name: String, value: NSNumber)

    /// Sets a measurement on this span with a specific unit.
    ///
    /// Setting a measurement with the same name on the same span multiple times only keeps the
    /// last value. Child span measurements are not forwarded to the root transaction.
    @objc(setMeasurement:value:unit:)
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit)

    /// Finishes the span by setting the end time.
    func finish()

    /// Finishes the span by setting the end time and span status.
    @objc(finishWithStatus:)
    func finish(status: SentrySpanStatus)

    /// Returns the trace information that could be sent as a sentry-trace header.
    func toTraceHeader() -> TraceHeader

    /// Returns the baggage HTTP header.
    func baggageHttpHeader() -> String?
}
#else
/// A span measuring one unit of work inside a transaction.
@objc(SentrySpan)
public protocol Span: SentrySerializable {
    /// Determines which trace the span belongs to.
    var traceId: SentryId { get set }

    /// Span id.
    var spanId: SpanId { get set }

    /// The id of the parent span.
    var parentSpanId: SpanId? { get set }

    /// The sampling decision of the trace.
    var sampled: SentrySampleDecision { get set }

    /// Short code identifying the type of operation the span is measuring.
    var operation: String { get set }

    /// The origin of the span indicates what created the span.
    ///
    /// Gets set by the SDK. Callers are not expected to set it. The protocol allows this value to
    /// be optional, and the SDK still always sends it.
    ///
    /// See https://develop.sentry.dev/sdk/performance/trace-origin
    var origin: String { get set }

    /// Longer description of the span's operation, which uniquely identifies the span but is
    /// consistent across instances of the span.
    var spanDescription: String? { get set }

    /// Describes the status of the transaction.
    var status: SentrySpanStatus { get set }

    /// The timestamp at which the span ended.
    var timestamp: Date? { get set }

    /// The start time of the span.
    var startTimestamp: Date? { get set }

    /// An arbitrary mapping of additional metadata of the span.
    var data: [String: Any] { get }

    /// Key-value pairs holding additional data about the span.
    var tags: [String: String] { get }

    /// Whether the span is finished.
    var isFinished: Bool { get }

    /// Retrieves a trace context from this tracer.
    var traceContext: TraceContext? { get }

    /// Starts a child span.
    /// - Parameter operation: Short code identifying the type of operation the span is measuring.
    @objc(startChildWithOperation:)
    func startChild(operation: String) -> any Span

    /// Starts a child span.
    /// - Parameters:
    ///   - operation: Defines the child span operation.
    ///   - description: Defines the child span description.
    @objc(startChildWithOperation:description:)
    func startChild(operation: String, description: String?) -> any Span

    /// Sets a value in ``data``.
    @objc(setDataValue:forKey:)
    func setData(value: Any?, key: String)

    /// Removes a data value.
    @objc(removeDataForKey:)
    func removeData(key: String)

    /// Sets a tag value.
    @objc(setTagValue:forKey:)
    func setTag(value: String, key: String)

    /// Removes a tag value.
    @objc(removeTagForKey:)
    func removeTag(key: String)

    /// Sets a measurement without a unit.
    ///
    /// When setting the measurement without the unit, no formatting is applied to the measurement
    /// value in the Sentry product, and the value is shown as is. Setting a measurement with the
    /// same name on the same transaction multiple times only keeps the last value.
    @objc(setMeasurement:value:)
    func setMeasurement(name: String, value: NSNumber)

    /// Sets a measurement with a specific unit.
    ///
    /// Setting a measurement with the same name on the same transaction multiple times only keeps
    /// the last value.
    @objc(setMeasurement:value:unit:)
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit)

    /// Finishes the span by setting the end time.
    func finish()

    /// Finishes the span by setting the end time and span status.
    @objc(finishWithStatus:)
    func finish(status: SentrySpanStatus)

    /// Returns the trace information that could be sent as a sentry-trace header.
    func toTraceHeader() -> TraceHeader

    /// Returns the baggage HTTP header.
    func baggageHttpHeader() -> String?

    /// Serializes the span. Restated so the requirement stays on `Span` as well as
    /// `SentrySerializable`.
    func serialize() -> [String: Any]
}
#endif

func sentrySpan(from object: Any?) -> Span {
    if let span = object as? Span {
        return span
    }
    SentrySDKLog.error(
        "Expected a Span and received \(String(describing: type(of: object))). Returning a no-op span."
    )
    return noOpSentrySpan()
}

func optionalSentrySpan(from object: Any?) -> Span? {
    if object == nil {
        return nil
    }
    guard let span = object as? Span else {
        SentrySDKLog.error(
            "Expected a Span and received \(String(describing: type(of: object)))."
        )
        return nil
    }
    return span
}

func noOpSentrySpan() -> Span {
    if let span = SentryNoOpSpan.shared() as? Span {
        return span
    }
    SentrySDKLog.error("SentryNoOpSpan is not a Span. Returning an empty span.")
    return UnavailableSpan()
}

private final class UnavailableSpan: NSObject {
    var traceId = SentryId.empty
    var spanId = SpanId()
    var parentSpanId: SpanId?
    var sampled = SentrySampleDecision.undecided
    var operation = ""
    var origin = "manual"
    var spanDescription: String?
    var status = SentrySpanStatus.undefined
    var timestamp: Date?
    var startTimestamp: Date?
    var data: [String: Any] { [:] }
    var tags: [String: String] { [:] }
    var isFinished = false
    var traceContext: TraceContext? { nil }

    func startChild(operation: String) -> any Span { self }

    func startChild(operation: String, description: String?) -> any Span { self }

    func setData(value: Any?, key: String) {}

    func removeData(key: String) {}

    func setTag(value: String, key: String) {}

    func removeTag(key: String) {}

    func setMeasurement(name: String, value: NSNumber) {}

    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit) {}

    func finish() {}

    func finish(status: SentrySpanStatus) {}

    func toTraceHeader() -> TraceHeader {
        TraceHeader(trace: traceId, spanId: spanId, sampled: sampled)
    }

    func baggageHttpHeader() -> String? { nil }

    #if !SDK_V10
    func serialize() -> [String: Any] { [:] }
    #endif
}

extension UnavailableSpan: Span {}

// Feature flag APIs live in this file so the public Span API has a clear home.
// These methods stay SPI while the public surface is being finalized.
extension Span {
    // swiftlint:disable:next missing_docs
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let span = self as? SentrySpanInternal else {
            return
        }
        span.addFeatureFlagInternal(name: name, result: result)
    }
}
