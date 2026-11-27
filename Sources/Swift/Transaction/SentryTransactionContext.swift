internal import _SentryPrivate
import Foundation

/// Context of a transaction that the SDK uses to start a trace.
@objc(SentryTransactionContext)
@objcMembers
open class TransactionContext: SpanContext {

    /// Transaction name.
    public let name: String

    /// Describes how the transaction name was determined.
    public let nameSource: SentryTransactionNameSource

    /// Rate of sampling.
    public var sampleRate: NSNumber?

    /// Random value used to determine if the span is sampled.
    public var sampleRand: NSNumber?

    /// Parent sampled.
    public var parentSampled: SentrySampleDecision = .undecided

    /// Parent sample rate used for this transaction.
    public var parentSampleRate: NSNumber?

    /// Parent random value used to determine if the trace is sampled.
    public var parentSampleRand: NSNumber?

    /// If app launch profiling is enabled via `SentryProfileOptions.profileAppStarts` and
    /// `SentryOptions.tracesSampler` and/or `SentryOptions.profilesSampler` are defined,
    /// `SentrySDK.startWithOptions` will call the sampler function with this property set to `true`,
    /// and the returned value will be stored to disk for the next launch to calculate a sampling
    /// decision on whether or not to run the profiler.
    public var forNextAppLaunch = false

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Profiling thread captured when this context is created.
    ///
    /// Exposed for tests that serialize a profile while the backing state is still mutable.
    @_spi(Private)
    @objc public var threadInfo: SentryThread?
#endif

    /// Creates a transaction context from an operation code.
    ///
    /// `SpanContext` provides this initializer. The transaction name stays empty and
    /// the name source is custom.
    ///
    /// These overrides stay `@nonobjc`. `SpanContext` calls its own initializers on
    /// `self`, and an Objective-C override would replace that chain and clear `name`.
    @nonobjc
    override public convenience init(operation: String) {
        self.init(name: "", operation: operation)
    }

    /// Creates a transaction context from an operation code and a sampling decision.
    ///
    /// `SpanContext` provides this initializer. The transaction name stays empty and
    /// the name source is custom.
    @nonobjc
    override public convenience init(operation: String, sampled: SentrySampleDecision) {
        self.init(
            name: "",
            operation: operation,
            sampled: sampled,
            sampleRate: nil,
            sampleRand: nil
        )
    }

    /// Creates a transaction context for an existing trace.
    ///
    /// `SpanContext` provides this initializer. The transaction name stays empty and
    /// the name source is custom.
    @nonobjc
    override public convenience init(
        trace: SentryId,
        spanId: SpanId,
        parentId: SpanId?,
        operation: String,
        sampled: SentrySampleDecision
    ) {
        self.init(
            trace: trace,
            spanId: spanId,
            parentId: parentId,
            operation: operation,
            spanDescription: nil,
            sampled: sampled
        )
    }

    /// Creates a transaction context for an existing trace with a span description.
    ///
    /// `SpanContext` provides this initializer. The transaction name stays empty and
    /// the name source is custom.
    @nonobjc
    override public convenience init(
        trace: SentryId,
        spanId: SpanId,
        parentId: SpanId?,
        operation: String,
        spanDescription: String?,
        sampled: SentrySampleDecision
    ) {
        self.init(
            name: "",
            nameSource: .custom,
            operation: operation,
            origin: SentryTraceOriginManual,
            trace: trace,
            spanId: spanId,
            parentSpanId: parentId,
            spanDescription: spanDescription,
            sampled: sampled,
            parentSampled: .undecided,
            sampleRate: nil,
            parentSampleRate: nil,
            sampleRand: nil,
            parentSampleRand: nil
        )
    }

    /// Creates a transaction context with an SDK-defined name source, origin, and sampling decision.
    @_spi(Private)
    @objc(initWithName:nameSource:operation:origin:sampled:sampleRate:sampleRand:)
    public init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        sampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        sampleRand: NSNumber?
    ) {
        self.name = name
        self.nameSource = nameSource
        super.init(operation: operation, sampled: sampled)
        self.origin = origin
        self.sampleRate = sampleRate
        self.sampleRand = sampleRand
        finishInit(name: name)
    }

    private init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        spanDescription: String?,
        sampled: SentrySampleDecision,
        parentSampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        parentSampleRate: NSNumber?,
        sampleRand: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.name = name
        self.nameSource = nameSource
        self.parentSampled = parentSampled
        super.init(
            trace: trace,
            spanId: spanId,
            parentId: parentSpanId,
            operation: operation,
            spanDescription: spanDescription,
            sampled: sampled
        )
        self.origin = origin
        self.sampleRate = sampleRate
        self.sampleRand = sampleRand
        self.parentSampleRate = parentSampleRate
        self.parentSampleRand = parentSampleRand
        finishInit(name: name)
    }

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Returns the profiling thread captured for this context.
    @_spi(Private)
    @objc public func sentry_threadInfo() -> SentryThread? {
        threadInfo
    }
#endif

    private func finishInit(name: String) {
        captureThreadInfo()
        SentrySDKLog.debug("Created transaction context with name \(name)")
    }

    private func captureThreadInfo() {
#if !(os(watchOS) || os(tvOS) || os(visionOS))
        threadInfo = sentry_currentThreadInfo()
#endif
    }
}

extension TransactionContext {
    /// Creates a transaction context.
    ///
    /// - Parameters:
    ///   - name: Transaction name.
    ///   - operation: The operation this span is measuring.
    @objc(initWithName:operation:)
    public convenience init(name: String, operation: String) {
        self.init(name: name, operation: operation, sampled: .undecided)
    }

    private convenience init(name: String, operation: String, sampled: SentrySampleDecision) {
        self.init(
            name: name,
            operation: operation,
            sampled: sampled,
            sampleRate: nil,
            sampleRand: nil
        )
    }

    /// Creates a transaction context with an explicit sampling decision.
    ///
    /// - Parameters:
    ///   - name: Transaction name.
    ///   - operation: The operation this span is measuring.
    ///   - sampled: Determines whether the trace should be sampled.
    ///   - sampleRate: Rate of sampling.
    ///   - sampleRand: Random value used to determine if the span is sampled.
    @objc(initWithName:operation:sampled:sampleRate:sampleRand:)
    public convenience init(
        name: String,
        operation: String,
        sampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        sampleRand: NSNumber?
    ) {
        self.init(
            name: name,
            nameSource: .custom,
            operation: operation,
            origin: SentryTraceOriginManual,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )
    }

    /// Creates a transaction context for an existing trace.
    ///
    /// - Parameters:
    ///   - name: Transaction name.
    ///   - operation: The operation this span is measuring.
    ///   - trace: Trace id.
    ///   - spanId: Span id.
    ///   - parentSpanId: Parent span id.
    ///   - parentSampled: Whether the parent is sampled.
    ///   - parentSampleRate: Parent sample rate used for this transaction.
    ///   - parentSampleRand: Parent random value used to determine if the trace is sampled.
    @objc(initWithName:operation:traceId:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:)
    public convenience init(
        name: String,
        operation: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        parentSampled: SentrySampleDecision,
        parentSampleRate: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.init(
            name: name,
            nameSource: .custom,
            operation: operation,
            origin: SentryTraceOriginManual,
            trace: trace,
            spanId: spanId,
            parentSpanId: parentSpanId,
            parentSampled: parentSampled,
            parentSampleRate: parentSampleRate,
            parentSampleRand: parentSampleRand
        )
    }

    /// Creates a transaction context with an SDK-defined name source and origin.
    @_spi(Private)
    @objc(initWithName:nameSource:operation:origin:)
    public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String
    ) {
        self.init(
            name: name,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            sampled: .undecided,
            sampleRate: nil,
            sampleRand: nil
        )
    }

    /// Creates a transaction context for an existing trace with an SDK-defined name source.
    ///
    /// The span id is generated. The parent span id and parent sampling values stay unset.
    @_spi(Private)
    @objc(initWithName:nameSource:operation:origin:traceId:)
    public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId
    ) {
        self.init(
            name: name,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: trace,
            spanId: SpanId(),
            parentSpanId: nil,
            parentSampled: .undecided,
            parentSampleRate: nil,
            parentSampleRand: nil
        )
    }

    /// Creates a transaction context for an existing trace with an SDK-defined name source.
    @_spi(Private)
    @objc(initWithName:nameSource:operation:origin:traceId:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:)
    public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        parentSampled: SentrySampleDecision,
        parentSampleRate: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.init(
            name: name,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: trace,
            spanId: spanId,
            parentSpanId: parentSpanId,
            sampled: .undecided,
            parentSampled: parentSampled,
            sampleRate: nil,
            parentSampleRate: parentSampleRate,
            sampleRand: nil,
            parentSampleRand: parentSampleRand
        )
    }

    /// Creates a transaction context for an existing trace with sampling fields from the SDK.
    @_spi(Private)
    @objc(initWithName:nameSource:operation:origin:traceId:spanId:parentSpanId:sampled:parentSampled:sampleRate:parentSampleRate:sampleRand:parentSampleRand:)
    public convenience init(
        name: String,
        nameSource: SentryTransactionNameSource,
        operation: String,
        origin: String,
        trace: SentryId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        sampled: SentrySampleDecision,
        parentSampled: SentrySampleDecision,
        sampleRate: NSNumber?,
        parentSampleRate: NSNumber?,
        sampleRand: NSNumber?,
        parentSampleRand: NSNumber?
    ) {
        self.init(
            name: name,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: trace,
            spanId: spanId,
            parentSpanId: parentSpanId,
            spanDescription: nil,
            sampled: sampled,
            parentSampled: parentSampled,
            sampleRate: sampleRate,
            parentSampleRate: parentSampleRate,
            sampleRand: sampleRand,
            parentSampleRand: parentSampleRand
        )
    }
}
