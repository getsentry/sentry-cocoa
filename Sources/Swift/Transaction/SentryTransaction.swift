internal import _SentryPrivate
import Foundation

/// An event containing a trace and its child spans.
@objc(SentryTransaction)
public class Transaction: Event {
    internal var trace: SentryTracer

    /// The child spans belonging to this transaction.
    @objc public var spans: [any Span] = []

    /// The names of views shown while the transaction was active.
    @_spi(Private) @objc public var viewNames: [String]?

    /// The trace associated with this transaction.
    @_spi(Private) @objc(trace) public var traceObject: AnyObject? {
        get { trace }
        set {
            guard let newTrace = newValue as? SentryTracer else {
                SentrySDKLog.error("Cannot assign an invalid trace to a transaction.")
                return
            }
            trace = newTrace
        }
    }

    internal init(trace: SentryTracer, children: [any Span]) {
        self.trace = trace
        self.spans = children
        super.init()
        self.timestamp = trace.timestamp
        self.startTimestamp = trace.startTimestamp
        self.type = SentryEnvelopeItemTypes.transaction
    }

    /// Creates a transaction from an SDK-internal tracer object and child spans.
    @_spi(Private)
    @objc(initWithTrace:children:)
    public convenience init?(traceObject: AnyObject?, children: [any Span]) {
        // This initializer is an Objective-C bridge for SDK-internal callers, which previously
        // accepted only SentryTracer in SentryTransaction+Private.h.
        guard let trace = traceObject as? SentryTracer else {
            return nil
        }
        self.init(trace: trace, children: children)
    }

    /// Unavailable. Transactions must be initialized with a trace.
    /// Kept internal so the resilient interface does not restate Event.init().
    @available(*, unavailable)
    required init() {
        fatalError("init() is unavailable")
    }

    @available(*, unavailable)
    @objc public override init(level: SentryLevel) {
        fatalError("init(level:) is unavailable")
    }

    /// Unavailable. Transactions cannot be initialized from an error.
    @available(*, unavailable)
    @objc public convenience init(error: Error) {
        fatalError("init(error:) is unavailable")
    }

    @objc public override var tags: [String: String]? {
        get {
            return (super.tags ?? [:]).merging(trace.tags) { _, tracerValue in
                tracerValue
            }
        }
        set {
            for key in trace.tags.keys {
                trace.removeTag(key: key)
            }

            super.tags = nil

            for (key, value) in newValue ?? [:] {
                trace.setTag(value: value, key: key)
            }
        }
    }

#if SDK_V10
    @objc override func serialize() -> [String: Any] {
        serializeTransaction()
    }
#else
    @_spi(Private) public override func serialize() -> [String: Any] {
        serializeTransaction()
    }
#endif

    private func serializeTransaction() -> [String: Any] {
        var serializedData = super.serialize()
#if SDK_V10
        serializedData["spans"] = spans.compactMap {
            ($0 as? SentryInternalSerializable)?.serialize()
        }
#else
        serializedData["spans"] = spans.map { $0.serialize() }
#endif

        var mutableContext = serializedData["contexts"] as? [String: Any] ?? [:]

#if !(os(watchOS) || os(tvOS) || os(visionOS))
        var profileContextData: [String: Any] = [:]
        profileContextData["profiler_id"] = trace.value(forKey: "profileSessionID") as? String
        mutableContext["profile"] = profileContextData
#endif

        mutableContext["trace"] = trace.serialize()
        serializedData["contexts"] = mutableContext

        let traceTags = SentrySanitizerUtils.sanitizedDictionary(trace.tags as NSDictionary)
        if var tags = serializedData["tags"] as? [String: Any] {
            tags.merge(traceTags) { _, tracerValue in tracerValue }
            serializedData["tags"] = tags
        } else {
            serializedData["tags"] = traceTags
        }

        let traceData = SentrySanitizerUtils.sanitizedDictionary(trace.data as NSDictionary)
        if var extra = serializedData["extra"] as? [String: Any] {
            extra.merge(traceData) { _, tracerValue in tracerValue }
            serializedData["extra"] = extra
        } else {
            serializedData["extra"] = traceData
        }

        if let measurements = trace.value(forKey: "measurements") as? [String: SentryMeasurementValue],
           !measurements.isEmpty {
            serializedData["measurements"] = measurements.mapValues { $0.serialize() }
        }

        let rawNameSource = trace.transactionContext.value(forKey: "nameSource") as? Int ?? 0
        let nameSource = SentryTransactionNameSource(rawValue: rawNameSource) ?? .custom
        serializedData["transaction"] = trace.transactionContext.name
        serializedData["transaction_info"] = [
            "source": string(for: nameSource)
        ]

        return serializedData
    }

    private func string(for source: SentryTransactionNameSource) -> String {
        switch source {
        case .custom:
            return "custom"
        case .url:
            return "url"
        case .route:
            return "route"
        case .view:
            return "view"
        case .component:
            return "component"
        case .sourceTask:
            return "task"
        }
    }
}
