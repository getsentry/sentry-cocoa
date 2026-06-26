// swiftlint:disable missing_docs

private let maxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

final class SentryFeatureFlagBuffer {
    private struct State {
        var evaluations: [SentryFeatureFlagEvaluation]
        var indexesByFlag: [String: Int]
    }

    private let maxSize: Int
    private let overflowBehavior: SentryFeatureFlagBufferOverflowBehavior
    private let state: SentryMutex<State>

    init(maxSize: Int,
         overflowBehavior: SentryFeatureFlagBufferOverflowBehavior,
         evaluations: [SentryFeatureFlagEvaluation] = []) {
        self.maxSize = maxSize
        self.overflowBehavior = overflowBehavior
        let capacity = max(maxSize, 0)
        var evals = evaluations
        evals.reserveCapacity(capacity)
        var indexes = [String: Int]()
        indexes.reserveCapacity(capacity)
        self.state = SentryMutex(State(evaluations: evals, indexesByFlag: indexes))
        state.withLock { Self.rebuildIndexes(&$0) }
    }

    static func scopeBuffer() -> SentryFeatureFlagBuffer {
        SentryFeatureFlagBuffer(
            // Error events record the 100 most recent, unique feature flag evaluations.
            // https://develop.sentry.dev/sdk/foundations/client/integrations/feature-flags/#tracking-feature-flag-evaluations
            maxSize: maxScopeFeatureFlags,
            overflowBehavior: .dropOldest
        )
    }

    static func spanBuffer() -> SentryFeatureFlagBuffer {
        SentryFeatureFlagBuffer(
            // Spans track the first 10 feature flags evaluated within the span's scope.
            // https://develop.sentry.dev/sdk/foundations/client/integrations/feature-flags/#tracking-feature-flag-evaluations
            maxSize: maxSpanFeatureFlags,
            overflowBehavior: .rejectNew
        )
    }

    var allEvaluations: [SentryFeatureFlagEvaluation] {
        state.withLock { $0.evaluations }
    }

    func add<Value: SentryFeatureFlagValue>(name: String, value: Value) {
        state.withLock { state in
            guard maxSize > 0 else {
                return
            }
            let evaluation = SentryFeatureFlagEvaluation(flag: name, result: value.asSentryFeatureFlagValue)
            if let existingIndex = state.indexesByFlag[evaluation.flag] {
                switch overflowBehavior {
                case .dropOldest:
                    state.evaluations.remove(at: existingIndex)
                    state.evaluations.append(evaluation)
                    Self.rebuildIndexes(&state)
                case .rejectNew:
                    state.evaluations[existingIndex] = evaluation
                }
                return
            }

            if state.evaluations.count >= maxSize {
                switch overflowBehavior {
                case .dropOldest:
                    state.evaluations.removeFirst()
                    Self.rebuildIndexes(&state)
                case .rejectNew:
                    return
                }
            }

            state.indexesByFlag[evaluation.flag] = state.evaluations.count
            state.evaluations.append(evaluation)
        }
    }

    func remove(name: String) {
        state.withLock { state in
            guard let index = state.indexesByFlag[name] else {
                return
            }
            state.evaluations.remove(at: index)
            Self.rebuildIndexes(&state)
        }
    }

    func removeAll() {
        state.withLock { state in
            state.evaluations.removeAll(keepingCapacity: true)
            state.indexesByFlag.removeAll(keepingCapacity: true)
        }
    }

    func serializeForContext() -> [String: Any]? {
        let values = allEvaluations.map { $0.serializeForContext() }
        guard !values.isEmpty else {
            return nil
        }
        return ["values": values]
    }

    func serializeForSpanData() -> [String: Any] {
        return allEvaluations.reduce(into: [String: Any]()) { result, evaluation in
            result[evaluation.spanDataKey] = evaluation.result.serializedValue
        }
    }

    func copy() -> SentryFeatureFlagBuffer {
        return SentryFeatureFlagBuffer(
            maxSize: maxSize,
            overflowBehavior: overflowBehavior,
            evaluations: allEvaluations
        )
    }

    private static func rebuildIndexes(_ state: inout State) {
        state.indexesByFlag.removeAll(keepingCapacity: true)
        for (index, evaluation) in state.evaluations.enumerated() {
            state.indexesByFlag[evaluation.flag] = index
        }
    }
}
// swiftlint:enable missing_docs
