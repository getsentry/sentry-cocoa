// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

private let defaultMaxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

@_spi(Private)
@objc(SentryFeatureFlagStorage)
public final class SentryFeatureFlagStorage: NSObject {
    private let buffer: SentryFeatureFlagBuffer

    private init(buffer: SentryFeatureFlagBuffer) {
        self.buffer = buffer
        super.init()
    }

    @objc(scopeStorage)
    public static func scopeStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(
            buffer: SentryFeatureFlagBuffer(
                maxSize: defaultMaxScopeFeatureFlags,
                overflowBehavior: .dropOldest
            )
        )
    }

    @objc(spanStorage)
    public static func spanStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(
            buffer: SentryFeatureFlagBuffer(
                maxSize: maxSpanFeatureFlags,
                overflowBehavior: .rejectNew
            )
        )
    }

    var allEvaluations: [SentryFeatureFlagEvaluation] {
        buffer.allEvaluations
    }

    func addFeatureFlag<Value: SentryFeatureFlagValue>(name: String, result: Value) {
        buffer.add(name: name, value: result)
    }

    @objc(removeAll)
    public func removeAll() {
        buffer.removeAll()
    }

    @objc(copyStorage)
    public func copyStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(buffer: buffer.copyBuffer())
    }

    @objc(serializeForContext)
    public func serializeForContext() -> [String: Any]? {
        buffer.serializeForContext()
    }

    @objc(serializeForSpanData)
    public func serializeForSpanData() -> [String: Any] {
        buffer.serializeForSpanData()
    }
}

extension Scope {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let storage = featureFlagStorage as? SentryFeatureFlagStorage else {
            return
        }
        storage.addFeatureFlag(name: name, result: result)
    }
}

extension Span {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let storage = (self as? SentrySpanInternal)?.featureFlagStorage as? SentryFeatureFlagStorage else {
            return
        }
        storage.addFeatureFlag(name: name, result: result)
    }
}
// swiftlint:enable missing_docs
