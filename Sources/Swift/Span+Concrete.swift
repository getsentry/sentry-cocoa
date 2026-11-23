internal import _SentryPrivate
import Foundation

// These methods are `@nonobjc` so they do not replace the Objective-C implementations. Swift
// call sites on the concrete class use them. The cast reaches the Objective-C method through the
// protocol witness.
extension SentrySpanInternal {
    func addFeatureFlag(name: String, result: Bool) {
        addFeatureFlagInternal(name: name, result: result)
    }

    @nonobjc @discardableResult
    func startChild(operation: String) -> any Span {
        guard let span = self as? Span else { return noOpSentrySpan() }
        return span.startChild(operation: operation)
    }

    @nonobjc @discardableResult
    func startChild(operation: String, description: String?) -> any Span {
        guard let span = self as? Span else { return noOpSentrySpan() }
        return span.startChild(operation: operation, description: description)
    }

    @nonobjc
    func finish() {
        (self as? Span)?.finish()
    }

    @nonobjc
    func finish(status: SentrySpanStatus) {
        (self as? Span)?.finish(status: status)
    }

    @nonobjc
    func setData(value: Any?, key: String) {
        (self as? Span)?.setData(value: value, key: key)
    }

    @nonobjc
    func removeData(key: String) {
        (self as? Span)?.removeData(key: key)
    }

    @nonobjc
    func setTag(value: String, key: String) {
        (self as? Span)?.setTag(value: value, key: key)
    }

    @nonobjc
    func removeTag(key: String) {
        (self as? Span)?.removeTag(key: key)
    }

    @nonobjc
    func setMeasurement(name: String, value: NSNumber) {
        (self as? Span)?.setMeasurement(name: name, value: value)
    }

    @nonobjc
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit) {
        (self as? Span)?.setMeasurement(name: name, value: value, unit: unit)
    }

    @nonobjc
    func toTraceHeader() -> TraceHeader {
        guard let span = self as? Span else {
            return noOpSentrySpan().toTraceHeader()
        }
        return span.toTraceHeader()
    }

    @nonobjc
    func baggageHttpHeader() -> String? {
        (self as? Span)?.baggageHttpHeader()
    }

    @nonobjc
    var traceContext: TraceContext? {
        (self as? Span)?.traceContext
    }
}

extension SentryTracer {
    @nonobjc
    var shouldIgnoreWaitForChildrenCallback: ((any Span) -> Bool)? {
        get {
            guard let callback = shouldIgnoreWaitForChildrenCallbackObject else { return nil }
            return { span in callback(span) }
        }
        set {
            shouldIgnoreWaitForChildrenCallbackObject = newValue.map { callback in
                { object in
                    guard let span = object as? Span else {
                        SentrySDKLog.error("Wait-for-children callback received a value that is not a Span.")
                        return false
                    }
                    return callback(span)
                }
            }
        }
    }
}

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
extension SentryAppStartMeasurement {
    @nonobjc
    var extendedAppStartSpan: (any Span)? {
        get { optionalSentrySpan(from: extendedAppStartSpanObject) }
        set { extendedAppStartSpanObject = newValue }
    }
}
#endif
