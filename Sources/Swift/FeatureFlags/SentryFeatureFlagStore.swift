// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

private let maxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

@_spi(Private)
@objc(SentryFeatureFlagStorage)
public final class SentryFeatureFlagStorage: NSObject {
    private let buffer: SentryFeatureFlagBuffer

    private init(buffer: SentryFeatureFlagBuffer) {
        self.buffer = buffer
        super.init()
    }

    @objc
    public static func scopeStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(
            buffer: SentryFeatureFlagBuffer(
                // Error events record the 100 most recent, unique feature flag evaluations.
                // https://develop.sentry.dev/sdk/foundations/client/integrations/feature-flags/#tracking-feature-flag-evaluations
                maxSize: maxScopeFeatureFlags,
                overflowBehavior: .dropOldest
            )
        )
    }

    @objc
    public static func spanStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(
            buffer: SentryFeatureFlagBuffer(
                // Spans track the first 10 feature flags evaluated within the span's scope.
                // https://develop.sentry.dev/sdk/foundations/client/integrations/feature-flags/#tracking-feature-flag-evaluations
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

    func removeFeatureFlag(name: String) {
        buffer.remove(name: name)
    }

    @objc
    public func removeAll() {
        buffer.removeAll()
    }

    @objc
    public func copyStorage() -> SentryFeatureFlagStorage {
        SentryFeatureFlagStorage(buffer: buffer.copy())
    }

    @objc
    public func serializeForContext() -> [String: Any]? {
        buffer.serializeForContext()
    }

    @objc
    public func serializeForSpanData() -> [String: Any] {
        buffer.serializeForSpanData()
    }
}
// swiftlint:enable missing_docs
