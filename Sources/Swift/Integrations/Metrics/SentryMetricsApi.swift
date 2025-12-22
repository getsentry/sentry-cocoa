@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryMetricsApiDependencies {
    associatedtype Integration: SentryMetricsIntegrationProtocol

    var isSDKEnabled: Bool { get }
    var isMetricsEnabled: Bool { get }
    var scope: Scope { get }
    var metricsIntegration: Integration? { get }
}

struct SentryMetricsApi<Dependencies: SentryMetricsApiDependencies>: SentryMetricsApiProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func count(key: String, value: UInt, unit: SentryMetricsUnit? = nil, attributes: [String: SentryAttributeValuable] = [:]) {
        recordMetric(name: key, value: .counter(value), unit: unit, attributes: attributes)
    }

    func distribution(key: String, value: Double, unit: SentryMetricsUnit? = nil, attributes: [String: SentryAttributeValuable] = [:]) {
        recordMetric(name: key, value: .distribution(value), unit: unit, attributes: attributes)
    }

    func gauge(key: String, value: Double, unit: SentryMetricsUnit? = nil, attributes: [String: SentryAttributeValuable] = [:]
    ) {
        recordMetric(name: key, value: .gauge(value), unit: unit, attributes: attributes)
    }

    // MARK: - Private

    private func recordMetric(
        name: String,
        value: SentryMetric.Value,
        unit: SentryMetricsUnit?,
        attributes: [String: SentryAttributeValuable]
    ) {
        guard dependencies.isSDKEnabled && dependencies.isMetricsEnabled else {
            return
        }
        guard let integration = dependencies.metricsIntegration else {
            return
        }

        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId.empty, // Will be set by batcher from scope
            name: name,
            value: value,
            unit: unit,
            attributes: attributes.mapValues { attributable in
                attributable.asAttributeValue
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

    var isMetricsEnabled: Bool {
        SentrySDKInternal.options?.enableMetrics == true
    }

    var scope: Scope {
        SentrySDKInternal.currentHub().scope
    }

    var metricsIntegration: SentryMetricsIntegration<SentryDependencyContainer>? {
        return SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration
    }
}
