// swiftlint:disable missing_docs
import Foundation

final class SentryFeatureFlagBuffer {
    private let maxSize: Int
    private let overflowBehavior: SentryFeatureFlagBufferOverflowBehavior
    private let lock = NSLock()
    private var evaluations: [SentryFeatureFlagEvaluation]

    convenience init(maxSize: Int, overflowBehavior: SentryFeatureFlagBufferOverflowBehavior) {
        self.init(maxSize: maxSize, overflowBehavior: overflowBehavior, evaluations: [])
    }

    private init(maxSize: Int,
                 overflowBehavior: SentryFeatureFlagBufferOverflowBehavior,
                 evaluations: [SentryFeatureFlagEvaluation]) {
        self.maxSize = maxSize
        self.overflowBehavior = overflowBehavior
        self.evaluations = evaluations
    }

    var allEvaluations: [SentryFeatureFlagEvaluation] {
        return lock.synchronized {
            evaluations
        }
    }

    func add<Value: SentryFeatureFlagValue>(name: String, value: Value) {
        add(name: name, value: value.asSentryFeatureFlagValue)
    }

    func add(name: String, value: SentryFeatureFlagValueContent) {
        lock.synchronized {
            guard maxSize > 0 else {
                return
            }

            let evaluation = SentryFeatureFlagEvaluation(flag: name, result: value)
            if let existingIndex = evaluations.firstIndex(where: { $0.flag == name }) {
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

    func copyBuffer() -> SentryFeatureFlagBuffer {
        return SentryFeatureFlagBuffer(
            maxSize: maxSize,
            overflowBehavior: overflowBehavior,
            evaluations: allEvaluations
        )
    }
}
// swiftlint:enable missing_docs
