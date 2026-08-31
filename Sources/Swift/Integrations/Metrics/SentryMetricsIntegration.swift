internal import _SentryPrivate

protocol SentryMetricsIntegrationProtocol {
    func addMetric(_ metric: SentryMetric, scope: Scope, currentScope: Scope?)
}

/// Empty on purpose. Required by the SwiftIntegration protocol constraint.
protocol SentryMetricsIntegrationDependencies {}

final class SentryMetricsIntegration<Dependencies: SentryMetricsIntegrationDependencies>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol {
    private let scopeMetaData: SentryDefaultScopeApplyingMetadata
    private let beforeSendMetric: ((SentryMetric) -> SentryMetric?)?

    init?(with options: Options, dependencies _: Dependencies) {
        guard options.enableMetrics else { return nil }

#if SDK_V10
        let shouldAddDefaultUserId = options.dataCollection.userInfo
#else
        let shouldAddDefaultUserId = options.sendDefaultPii
#endif // SDK_V10
        self.scopeMetaData = SentryDefaultScopeApplyingMetadata(
            environment: options.environment,
            releaseName: options.releaseName,
            cacheDirectoryPath: options.cacheDirectoryPath,
            shouldAddDefaultUserId: shouldAddDefaultUserId
        )

        self.beforeSendMetric = options.beforeSendMetric

        super.init()
    }

    func uninstall() {
        // Empty on purpose. Nothing to uninstall.
    }

    static var name: String {
        "SentryMetricsIntegration"
    }

    // MARK: - Public API for Metrics

    func addMetric(_ metric: SentryMetric, scope: Scope, currentScope: Scope? = nil) {
        // We go directly to the client instead of through the hub because metrics only have a
        // static API today and the hub doesn't implement any metrics methods. Ideally, metrics should also go
        // through the hub to align with other telemetry types.
        guard let client = SentrySDKInternal.currentHub().getClient() else {
            SentrySDKLog.debug("MetricsIntegration: No client available, dropping metric")
            return
        }

        // Bail out before scope enrichment and the beforeSendMetric callback so we don't run user
        // code or do unnecessary work when the SDK is disabled. Mirrors the early return in
        // SentryClient's log capture.
        guard !client.isDisabled else {
            client.logDisabledMessage()
            return
        }

        var mutableMetric = metric
        // Merge the current scope's custom attributes before applying the global scope so the
        // precedence is: caller attributes > current scope > global scope. Only custom attributes
        // are taken from the current scope; user, span, and trace correlation stay on the global
        // scope, which addAttributesToItem applies below.
        if let currentScope {
            var attributes = mutableMetric.attributesDict
            for (key, value) in currentScope.attributesDict where attributes[key] == nil {
                attributes[key] = value
            }
            mutableMetric.attributesDict = attributes
        }
        scope.addAttributesToItem(&mutableMetric, metadata: self.scopeMetaData)

        if let beforeSendMetric = beforeSendMetric {
            // Create a non-mutated copy of the metric, because it could be modified by the SDK user's `beforeSendMetric` 
            let metricToSend = mutableMetric
            guard let processedItem = beforeSendMetric(mutableMetric) else {
                SentrySDKLog.debug("Metric dropped by beforeSendMetric callback.")
                // The byte size is computed lazily on a background queue inside the client, so the
                // calling thread isn't blocked by serialization.
                client.recordDroppedTraceMetric(inClientReport: SentryMetricObjC(metric: metricToSend))
                return
            }
            mutableMetric = processedItem
        }

        client.captureMetric(mutableMetric)
    }
}

// MARK: - SentryClientInternal Metrics Extension

extension SentryClientInternal {

    /// Captures a metric by forwarding it to the telemetry processor's metrics buffer.
    /// This method stays entirely in Swift, avoiding the ObjC boundary since SentryMetric is a Swift struct.
    /// `SentryMetricsIntegration.addMetric` already drops metrics (and logs) when the SDK is disabled;
    /// this guard is a defensive safety net so a future caller can't bypass that gate.
    func captureMetric(_ metric: SentryMetric) {
        guard !self.isDisabled else {
            self.logDisabledMessage()
            return
        }

        guard let processor = self.getTelemetryProcessor() as? SentryTelemetryProcessor else {
            SentrySDKLog.error("Cannot capture metric because the telemetry processor is not available. Discarding metric. This is unexpected and indicates a configuration issue.")
            return
        }
        processor.add(metric: metric)
    }
}
