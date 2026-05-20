internal import SentrySwift
import Foundation

/// Context describing a transaction's identity and sampling state.
///
/// In the SDK this class subclasses `SpanContext`, but per the plan's
/// flatten-the-hierarchy decision we mirror only the public surface as a
/// standalone wrapper.
@objc(SOCSentryTransactionContext)
public final class TransactionContext: NSObject {
    internal let wrapped: SentrySwift.TransactionContext

    internal init(_ wrapped: SentrySwift.TransactionContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(name: String, operation: String) {
        self.wrapped = SentrySwift.TransactionContext(name: name, operation: operation)
        super.init()
    }

    @objc public init(
        name: String,
        operation: String,
        sampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        sampleRand: NSNumber?
    ) {
        self.wrapped = SentrySwift.TransactionContext(
            name: name,
            operation: operation,
            sampled: sampled.underlying,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )
        super.init()
    }

    @objc public init(
        name: String,
        operation: String,
        traceId: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        parentSampled: SentrySampleDecision,
        parentSampleRate: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.wrapped = SentrySwift.TransactionContext(
            name: name,
            operation: operation,
            trace: traceId.wrapped,
            spanId: spanId.wrapped,
            parentSpanId: parentSpanId?.wrapped,
            parentSampled: parentSampled.underlying,
            parentSampleRate: parentSampleRate,
            parentSampleRand: parentSampleRand
        )
        super.init()
    }

    @objc public var name: String { wrapped.name }

    @objc public var sampleRate: NSNumber? {
        get { wrapped.sampleRate }
        set { wrapped.sampleRate = newValue }
    }

    @objc public var sampleRand: NSNumber? {
        get { wrapped.sampleRand }
        set { wrapped.sampleRand = newValue }
    }

    @objc public var parentSampled: SentrySampleDecision {
        get { SentrySampleDecision(wrapped.parentSampled) }
        set { wrapped.parentSampled = newValue.underlying }
    }

    @objc public var parentSampleRate: NSNumber? {
        get { wrapped.parentSampleRate }
        set { wrapped.parentSampleRate = newValue }
    }

    @objc public var parentSampleRand: NSNumber? {
        get { wrapped.parentSampleRand }
        set { wrapped.parentSampleRand = newValue }
    }

    @objc public var forNextAppLaunch: Bool {
        get { wrapped.forNextAppLaunch }
        set { wrapped.forNextAppLaunch = newValue }
    }

    // Inherited from the underlying `SpanContext`:

    @objc public var traceId: SentryId { SentryId(wrapped.traceId) }
    @objc public var spanId: SpanId { SpanId(wrapped.spanId) }
    @objc public var parentSpanId: SpanId? { wrapped.parentSpanId.map(SpanId.init) }
    @objc public var sampled: SentrySampleDecision { SentrySampleDecision(wrapped.sampled) }
    @objc public var operation: String { wrapped.operation }
    @objc public var spanDescription: String? { wrapped.spanDescription }
    @objc public var origin: String {
        get { wrapped.origin }
        set { wrapped.origin = newValue }
    }
}
