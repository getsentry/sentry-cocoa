// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public final class SentryObjCSpan: NSObject {
    internal let wrapped: any Span

    internal init(_ wrapped: any Span) {
        self.wrapped = wrapped
    }

    @objc public var traceId: SentryObjCId {
        get { SentryObjCId(wrapped.traceId) }
        set { wrapped.traceId = newValue.wrapped }
    }

    @objc public var spanId: SentryObjCSpanId {
        get { SentryObjCSpanId(wrapped.spanId) }
        set { wrapped.spanId = newValue.wrapped }
    }

    @objc public var parentSpanId: SentryObjCSpanId? {
        get {
            guard let p = wrapped.parentSpanId else { return nil }
            return SentryObjCSpanId(p)
        }
        set { wrapped.parentSpanId = newValue?.wrapped }
    }

    @objc public var sampled: SentryObjCSampleDecision {
        get { SentryObjCSampleDecision(wrapped.sampled) }
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

    @objc public var status: SentryObjCSpanStatus {
        get { SentryObjCSpanStatus(wrapped.status) }
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

    @objc public var data: [String: Any] {
        wrapped.data
    }

    @objc public var tags: [String: String] {
        wrapped.tags
    }

    @objc public var isFinished: Bool {
        wrapped.isFinished
    }

    @objc public var traceContext: SentryObjCTraceContext? {
        guard let tc = wrapped.traceContext else { return nil }
        return SentryObjCTraceContext(tc)
    }

    @objc public func startChild(operation: String) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startChild(operation: operation))
    }

    @objc public func startChild(operation: String, description: String?) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startChild(operation: operation, description: description))
    }

    @objc public func setData(value: Any?, key: String) {
        wrapped.setData(value: value, key: key)
    }

    @objc public func removeData(key: String) {
        wrapped.removeData(key: key)
    }

    @objc public func setTag(value: String, key: String) {
        wrapped.setTag(value: value, key: key)
    }

    @objc public func removeTag(key: String) {
        wrapped.removeTag(key: key)
    }

    @objc public func setMeasurement(name: String, value: NSNumber) {
        wrapped.setMeasurement(name: name, value: value)
    }

    @objc public func setMeasurement(name: String, value: NSNumber, unit: SentryObjCMeasurementUnit) {
        wrapped.setMeasurement(name: name, value: value, unit: unit.wrapped)
    }

    @objc public func finish() {
        wrapped.finish()
    }

    @objc public func finish(status: SentryObjCSpanStatus) {
        wrapped.finish(status: status.underlying)
    }

    @objc public func toTraceHeader() -> SentryObjCTraceHeader {
        SentryObjCTraceHeader(wrapped.toTraceHeader())
    }

    @objc public func baggageHttpHeader() -> String? {
        wrapped.baggageHttpHeader()
    }
}

// swiftlint:enable missing_docs
