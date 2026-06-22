// swiftlint:disable missing_docs
import Foundation

private let maxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

final class SentryFeatureFlagBuffer {
    private let maxSize: Int
    private let overflowBehavior: SentryFeatureFlagBufferOverflowBehavior
    private let lock = NSLock()
    private var evaluations: [SentryFeatureFlagEvaluation]

    init(maxSize: Int,
         overflowBehavior: SentryFeatureFlagBufferOverflowBehavior,
         evaluations: [SentryFeatureFlagEvaluation] = []) {
        self.maxSize = maxSize
        self.overflowBehavior = overflowBehavior
        self.evaluations = evaluations
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
            if let existingIndex = evaluations.firstIndex(where: { $0.flag == evaluation.flag }) {
                switch overflowBehavior {
                case .dropOldest:
                    evaluations.remove(at: existingIndex)
                    evaluations.append(evaluation)
                case .rejectNew:
                    evaluations[existingIndex] = evaluation
                }
                return
            }

            if evaluations.count >= maxSize {
                switch overflowBehavior {
                case .dropOldest:
                    evaluations.removeFirst()
                case .rejectNew:
                    return
                }
            }

            evaluations.append(evaluation)
        }
    }

    func remove(name: String) {
        lock.synchronized {
            evaluations.removeAll { $0.flag == name }
        }
    }

    func removeAll() {
        lock.synchronized {
            evaluations.removeAll()
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
}
// swiftlint:enable missing_docs
