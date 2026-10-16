internal import _SentryPrivate
import Foundation

@objc(SentryTransaction)
/// An event containing a trace and its child spans.
open class Transaction: Event {
    internal var trace: SentryTracer!

    /// The child spans belonging to this transaction.
    @objc open var spans: [any Span] = []

    /// The names of views shown while the transaction was active.
    @_spi(Private) @objc public var viewNames: [String]?

    @_spi(Private) @objc(trace) public var traceObject: AnyObject? {
        get { trace }
        set { trace = newValue as? SentryTracer }
    }

    internal init(trace: SentryTracer, children: [any Span]) {
        self.trace = trace
        self.spans = children
        super.init()
        self.timestamp = trace.timestamp
        self.startTimestamp = trace.startTimestamp
        self.type = SentryEnvelopeItemTypes.transaction
    }

    @_spi(Private)
    @objc(initWithTrace:children:)
    public convenience init?(traceObject: AnyObject, children: [any Span]) {
        // This initializer is an Objective-C bridge for SDK-internal callers, which previously
        // accepted only SentryTracer in SentryTransaction+Private.h.
        guard let trace = traceObject as? SentryTracer else {
            return nil
        }
        self.init(trace: trace, children: children)
    }

    @available(*, unavailable)
    public required convenience init() {
        fatalError("init() is unavailable")
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    @objc public override init(level: SentryLevel) {
        super.init(level: level)
    }
#endif

    @objc open override var tags: [String: String]? {
        get {
            guard let trace else {
                return super.tags
            }

            return (super.tags ?? [:]).merging(trace.tags) { _, tracerValue in
                tracerValue
            }
        }
        set {
            guard let trace else {
                super.tags = newValue
                return
            }

            for key in trace.tags.keys {
                trace.removeTag(key: key)
            }

            super.tags = nil

            for (key, value) in newValue ?? [:] {
                trace.setTag(value: value, key: key)
            }
        }
    }

    @_spi(Private) open override func serialize() -> [String: Any] {
        var serializedData = super.serialize()
        serializedData["spans"] = spans.map { $0.serialize() }

        var mutableContext = serializedData["contexts"] as? [String: Any] ?? [:]

#if !(os(watchOS) || os(tvOS) || os(visionOS))
        var profileContextData: [String: Any] = [:]
        profileContextData["profiler_id"] = trace?.value(forKey: "profileSessionID") as? String
        mutableContext["profile"] = profileContextData
#endif

        mutableContext["trace"] = trace?.serialize()
        serializedData["contexts"] = mutableContext

        let traceTags = trace.map { sanitizedDictionary($0.tags as NSDictionary) } ?? [:]
        if var tags = serializedData["tags"] as? [String: Any] {
            tags.merge(traceTags) { _, tracerValue in tracerValue }
            serializedData["tags"] = tags
        } else {
            serializedData["tags"] = traceTags
        }

        let traceData = trace.map { sanitizedDictionary($0.data as NSDictionary) } ?? [:]
        if var extra = serializedData["extra"] as? [String: Any] {
            extra.merge(traceData) { _, tracerValue in tracerValue }
            serializedData["extra"] = extra
        } else {
            serializedData["extra"] = traceData
        }

        if let measurements = trace?.value(forKey: "measurements") as? [String: SentryMeasurementValue],
           !measurements.isEmpty {
            serializedData["measurements"] = measurements.mapValues { $0.serialize() }
        }

        if let trace {
            let rawNameSource = trace.transactionContext.value(forKey: "nameSource") as? Int ?? 0
            let nameSource = SentryTransactionNameSource(rawValue: rawNameSource) ?? .custom
            serializedData["transaction"] = trace.transactionContext.name
            serializedData["transaction_info"] = [
                "source": string(for: nameSource)
            ]
        }

        return serializedData
    }

    private func sanitizedDictionary(_ dictionary: NSDictionary?) -> [String: Any] {
        sentry_sanitize_dictionary(dictionary) as? [String: Any] ?? [:]
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
