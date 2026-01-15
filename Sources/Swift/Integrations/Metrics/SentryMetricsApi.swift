@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryMetricsApiDependencies {
    associatedtype Integration: SentryMetricsIntegrationProtocol

    var isSDKEnabled: Bool { get }
    var scope: Scope { get }
    var dateProvider: SentryCurrentDateProvider { get }

    /// The integration is nullable, meaning if it's not installed or not enabled, it will return nil
    var metricsIntegration: Integration? { get }
}

struct SentryMetricsApi<Dependencies: SentryMetricsApiDependencies>: SentryMetricsApiProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func count(key: String, value: UInt, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        recordMetric(name: key, value: .counter(value), unit: unit, attributes: attributes)
    }

    func distribution(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        recordMetric(name: key, value: .distribution(value), unit: unit, attributes: attributes)
    }

    func gauge(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]
    ) {
        recordMetric(name: key, value: .gauge(value), unit: unit, attributes: attributes)
    }

    // MARK: - Private

    private func recordMetric(
        name: String,
        value: SentryMetric.Value,
        unit: SentryUnit?,
        attributes: [String: SentryAttributeValue]
    ) {
        guard dependencies.isSDKEnabled else {
            SentrySDKLog.warning("Metric '\(name)' was not recorded because the Sentry SDK has not been started. Call SentrySDK.start(options:) first.")
            return
        }
        guard let integration = dependencies.metricsIntegration else {
            SentrySDKLog.warning("Metric '\(name)' was not recorded because metrics are disabled. Enable metrics by setting 'options.enableMetrics = true' when starting the SDK.")
            return
        }

        // Capture the traceId at metric creation time to ensure it reflects the active trace
        // when the metric was recorded, not when it gets flushed by the batcher.
        //
        // This logic is intentionally duplicated from BatcherScope.applyToItem (used by Logs)
        // for the following reasons:
        // 1. Safety: If batcher enrichment is skipped or fails, metrics still have valid traceIds
        //    rather than empty ones, which would break trace correlation entirely.
        // 2. Semantic correctness: A metric recorded during a network request should correlate
        //    with that request's trace, matching how we capture timestamp at creation time.
        // 3. Fail-safe redundancy: The batchers scope enrichment will overwrite this value, producing
        //    the same result but with a safety net for edge cases. We can not remove the duplication from
        //    the batcher scope because it is used by Logs and other integrations.
        //
        // When a span is active, use its traceId to ensure consistency with span_id.
        // Otherwise, fall back to propagationContext traceId.
        let traceId = dependencies.scope.span?.traceId ?? dependencies.scope.propagationContextTraceId

        let metric = SentryMetric(
            timestamp: dependencies.dateProvider.date(),
            traceId: traceId,
            name: name,
            value: value,
            unit: unit,
            attributes: attributes.mapValues { attributable in
                attributable.asSentryAttributeContent
            }
        )
        integration.addMetric(metric, scope: dependencies.scope)
    }
}

extension SentryDependencyContainer: SentryMetricsApiDependencies {
    typealias IntegrationDependencies = SentryDependencyContainer

    var isSDKEnabled: Bool {
        SentrySDKInternal.isEnabled
    }

    var scope: Scope {
        SentrySDKInternal.currentHub().scope
    }

    var metricsIntegration: SentryMetricsIntegration<SentryDependencyContainer>? {
        SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration
    }
}
