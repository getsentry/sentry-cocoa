@_implementationOnly import _SentryPrivate

protocol SentryMetricsIntegrationProtocol {
    func addMetric(_ metric: SentryMetric, scope: Scope)
}

/// Empty on purpose. Required by the SwiftIntegration protocol constraint.
protocol SentryMetricsIntegrationDependencies {}

final class SentryMetricsIntegration<Dependencies: SentryMetricsIntegrationDependencies>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol {
    private let scopeMetaData: SentryDefaultScopeApplyingMetadata
    private let beforeSendMetric: ((SentryMetric) -> SentryMetric?)?

    init?(with options: Options, dependencies _: Dependencies) {
        guard options.experimental.enableMetrics else { return nil }

        self.scopeMetaData = SentryDefaultScopeApplyingMetadata(
            environment: options.environment,
            releaseName: options.releaseName,
            cacheDirectoryPath: options.cacheDirectoryPath,
            sendDefaultPii: options.sendDefaultPii
        )

        self.beforeSendMetric = options.experimental.beforeSendMetric

        super.init()
    }

    func uninstall() {
        // Empty on purpose. Nothing to uninstall.
    }

    static var name: String {
        "SentryMetricsIntegration"
    }

    // MARK: - Public API for Metrics

    func addMetric(_ metric: SentryMetric, scope: Scope) {
        var mutableMetric = metric
        scope.addAttributesToItem(&mutableMetric, metadata: self.scopeMetaData)

        if let beforeSendMetric = beforeSendMetric {
            guard let processedItem = beforeSendMetric(mutableMetric) else {
                return
            }
            mutableMetric = processedItem
        }

        // We go directly to the client instead of through the hub because metrics only have a
        // static API today and the hub doesn't implement any metrics methods. Ideally, metrics should also go
        // through the hub to align with other telemetry types.
        guard let client = SentrySDKInternal.currentHub().getClient() else {
            SentrySDKLog.debug("MetricsIntegration: No client available, dropping metric")
            return
        }
        client.captureMetric(mutableMetric)
    }
}

// MARK: - SentryClientInternal Metrics Extension

extension SentryClientInternal {

    /// Captures a metric by forwarding it to the telemetry processor's metrics buffer.
    /// This method stays entirely in Swift, avoiding the ObjC boundary since SentryMetric is a Swift struct.
    func captureMetric(_ metric: SentryMetric) {
        guard let processor = self.getTelemetryProcessor() as? SentryTelemetryProcessor else {
            SentrySDKLog.error("Cannot capture metric because the telemetry processor is not available. Discarding metric. This is unexpected and indicates a configuration issue.")
            return
        }
        processor.add(metric: metric)
    }
}
