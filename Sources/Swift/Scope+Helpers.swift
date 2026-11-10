internal import _SentryPrivate
import Foundation

private let kSentryScopeSpanStatusSerializationKey = "status"

extension Scope {
    func applySpan(_ span: Span?, to event: Event) {
        var context = event.context ?? [:]
        let previousTraceId = context["trace"]?["trace_id"] as? String
        #if SDK_V10
        if event.type == SentryEnvelopeItemTypes.transaction, let transaction = event as? Transaction {
            // Transaction capture is asynchronous, so the scope may no longer hold its tracer.
            context["trace"] = transaction.trace.serialize()
        } else {
            context["trace"] = buildTraceContext(span)
        }
        #else
        context["trace"] = buildTraceContext(span)
        #endif
        event.context = context

        guard event.type != SentryEnvelopeItemTypes.transaction else { return }

        let updatedTraceId = context["trace"]?["trace_id"] as? String
        if let tracer = SentryTracer.getTracer(span) {
            event.transaction = tracer.transactionContext.name
        } else if span != nil, previousTraceId != nil, previousTraceId != updatedTraceId {
            event.transaction = nil
        }
    }

    func buildTraceContext(_ span: Span?) -> [String: Any] {
        #if SDK_V10
        // Public spans no longer require the SDK's internal serialization contract.
        if let serializable = span as? SentryInternalSerializable {
            return normalizedTraceContext(serializable.serialize())
        }
        return propagationContext.traceContextForEvent()
        #else
        if let span {
            return normalizedTraceContext(span.serialize())
        }
        return propagationContext.traceContextForEvent()
        #endif
    }

    private func normalizedTraceContext(_ dict: [String: Any]) -> [String: Any] {
        if dict[kSentryScopeSpanStatusSerializationKey] != nil {
            return dict
        }
        // Unfinished spans on the scope usually have no status. Default the trace context to OK
        // so it is not reported as undefined. Finishing a span still sets its own status.
        var mutable = dict
        mutable[kSentryScopeSpanStatusSerializationKey] = SentrySpanStatus.ok.name
        return mutable
    }

    /// Must be called while synchronized on `contextDictionary`.
    func updateFeatureFlagsContextLocked() {
        let featureFlags = featureFlagBuffer.serializeForContext()
        if let featureFlags, !featureFlags.isEmpty {
            contextDictionary["flags"] = featureFlags
        } else {
            contextDictionary.removeObject(forKey: "flags")
        }
        let contextCopy = contextDictionaryCopy()
        notifyObservers { $0.setContext(contextCopy) }
    }

    func observerSnapshot() -> [AnyObject] {
        synchronized(observersLock) { observers }
    }

    func notifyObservers(_ body: (SentryScopeObserver) -> Void) {
        for observer in observerSnapshot() {
            guard let observer = observer as? SentryScopeObserver else { continue }
            body(observer)
        }
    }

    /// Recursively overlays `source` onto `destination`. Nested dictionaries merge; other values replace.
    func mergeEntries(from source: NSDictionary, into destination: NSMutableDictionary) {
        source.enumerateKeysAndObjects { key, value, _ in
            if let sourceDictionary = value as? NSDictionary,
               let existing = destination[key] as? NSDictionary {
                let merged = NSMutableDictionary(dictionary: existing)
                mergeEntries(from: sourceDictionary, into: merged)
                destination[key] = merged
                return
            }
            destination[key] = value
        }
    }

    func contextDictionaryCopy() -> [String: [String: Any]] {
        if let context = contextDictionary.copy() as? [String: [String: Any]] {
            return context
        }
        // One non-dictionary value must not discard the dictionaries beside it.
        return bridgedContext(contextDictionary)
    }

    /// Keeps every top-level dictionary. A value that is not a dictionary cannot be stored on
    /// `Event.context`, but it must not cause the merged dictionaries to be thrown away.
    func bridgedContext(_ dictionary: NSDictionary) -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        dictionary.enumerateKeysAndObjects { key, value, _ in
            guard let key = key as? String, let nested = value as? NSDictionary else { return }
            var inner: [String: Any] = [:]
            nested.enumerateKeysAndObjects { innerKey, innerValue, _ in
                guard let innerKey = innerKey as? String else { return }
                inner[innerKey] = innerValue
            }
            result[key] = inner
        }
        return result
    }

    func stringDictionary(_ dictionary: NSMutableDictionary) -> [String: String] {
        dictionary.copy() as? [String: String] ?? [:]
    }

    func anyDictionary(_ dictionary: NSMutableDictionary) -> [String: Any] {
        dictionary.copy() as? [String: Any] ?? [:]
    }

    func stringArray(_ array: NSMutableArray) -> [String] {
        array.copy() as? [String] ?? []
    }

    func objects<T>(of type: T.Type, in array: NSMutableArray) -> [T] {
        array.compactMap { $0 as? T }
    }
}
