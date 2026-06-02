// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public final class SentryFeatureFlagBuffer: NSObject {
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
        super.init()
    }

    @objc public static func scopeBuffer(maxSize: Int) -> SentryFeatureFlagBuffer {
        return SentryFeatureFlagBuffer(maxSize: maxSize, overflowBehavior: .dropOldest)
    }

    @objc public static func spanBuffer(maxSize: Int) -> SentryFeatureFlagBuffer {
        return SentryFeatureFlagBuffer(maxSize: maxSize, overflowBehavior: .rejectNew)
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
                evaluations.remove(at: existingIndex)
                evaluations.append(evaluation)
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

    @objc public func addBooleanValue(_ value: Bool, forName name: String) {
        add(name: name, value: .boolean(value))
    }

    @objc public func removeAll() {
        lock.synchronized {
            evaluations.removeAll()
        }
    }

    @objc public func serializeForContext() -> [String: Any]? {
        let values = allEvaluations.map { $0.serializeForContext() }
        guard !values.isEmpty else {
            return nil
        }
        return ["values": values]
    }

    @objc public func serializeForSpanData() -> [String: Any] {
        return allEvaluations.reduce(into: [String: Any]()) { result, evaluation in
            result[evaluation.spanDataKey] = evaluation.result.serializedValue
        }
    }

    @objc public func copyBuffer() -> SentryFeatureFlagBuffer {
        return SentryFeatureFlagBuffer(
            maxSize: maxSize,
            overflowBehavior: overflowBehavior,
            evaluations: allEvaluations
        )
    }
}
// swiftlint:enable missing_docs
