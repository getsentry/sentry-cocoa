// swiftlint:disable missing_docs
import Foundation

private let maxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

final class SentryFeatureFlagBuffer {
    private let maxSize: Int
    private let overflowBehavior: SentryFeatureFlagBufferOverflowBehavior
    private let lock = NSLock()
    private var evaluations: [SentryFeatureFlagEvaluation]
    private var indexesByFlag: [String: Int]

    init(maxSize: Int,
         overflowBehavior: SentryFeatureFlagBufferOverflowBehavior,
         evaluations: [SentryFeatureFlagEvaluation] = []) {
        self.maxSize = maxSize
        self.overflowBehavior = overflowBehavior
        self.evaluations = evaluations
        self.indexesByFlag = [:]
        let capacity = max(maxSize, 0)
        self.evaluations.reserveCapacity(capacity)
        self.indexesByFlag.reserveCapacity(capacity)
        rebuildIndexes()
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
        return lock.synchronized {
            evaluations
        }
    }

    func add<Value: SentryFeatureFlagValue>(name: String, value: Value) {
        lock.synchronized {
            guard maxSize > 0 else {
                return
            }
            let evaluation = SentryFeatureFlagEvaluation(flag: name, result: value.asSentryFeatureFlagValue)
            if let existingIndex = indexesByFlag[evaluation.flag] {
                switch overflowBehavior {
                case .dropOldest:
                    evaluations.remove(at: existingIndex)
                    evaluations.append(evaluation)
                    rebuildIndexes()
                case .rejectNew:
                    evaluations[existingIndex] = evaluation
                }
                return
            }

            if evaluations.count >= maxSize {
                switch overflowBehavior {
                case .dropOldest:
                    evaluations.removeFirst()
                    rebuildIndexes()
                case .rejectNew:
                    return
                }
            }

            indexesByFlag[evaluation.flag] = evaluations.count
            evaluations.append(evaluation)
        }
    }

    func remove(name: String) {
        lock.synchronized {
            guard let index = indexesByFlag[name] else {
                return
            }
            evaluations.remove(at: index)
            rebuildIndexes()
        }
    }

    func removeAll() {
        lock.synchronized {
            evaluations.removeAll(keepingCapacity: true)
            indexesByFlag.removeAll(keepingCapacity: true)
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

    private func rebuildIndexes() {
        indexesByFlag.removeAll(keepingCapacity: true)
        for (index, evaluation) in evaluations.enumerated() {
            indexesByFlag[evaluation.flag] = index
        }
    }
}
// swiftlint:enable missing_docs
