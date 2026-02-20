@_implementationOnly import _SentryPrivate

protocol SentryMetricsIntegrationProtocol {
    func addMetric(_ metric: SentryMetric, scope: Scope)
}

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
typealias SentryMetricsIntegrationDependencies = DateProviderProvider & DispatchQueueWrapperProvider & NotificationCenterProvider
#else
typealias SentryMetricsIntegrationDependencies = DateProviderProvider & DispatchQueueWrapperProvider
#endif

final class SentryMetricsIntegration<Dependencies: SentryMetricsIntegrationDependencies>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol, FlushableIntegration {
    private let metricsBuffer: SentryMetricsTelemetryBuffer
    private let scopeMetaData: SentryDefaultScopeApplyingMetadata
    private let beforeSendMetric: ((SentryMetric) -> SentryMetric?)?

    convenience init?(with options: Options, dependencies: Dependencies) {
        #if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
        let itemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers(
            notificationCenter: dependencies.notificationCenterWrapper
        )
        #else
        let itemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers()
        #endif

        let metricsBuffer = DefaultSentryMetricsTelemetryBuffer(
            dateProvider: dependencies.dateProvider,
            dispatchQueue: dependencies.dispatchQueueWrapper,
            itemForwardingTriggers: itemForwardingTriggers,
            capturedDataCallback: { data, count in
                let hub = SentrySDKInternal.currentHub()
                guard let client = hub.getClient() else {
                    SentrySDKLog.debug("MetricsIntegration: No client available, dropping metrics")
                    return
                }
                client.captureMetricsData(data, with: NSNumber(value: count))
            }
        )

        self.init(with: options, dependencies: dependencies, metricsBuffer: metricsBuffer)
    }

    /// Initializer for testing that allows injecting a custom metrics buffer
    init?(with options: Options, dependencies: Dependencies, metricsBuffer: SentryMetricsTelemetryBuffer) {
        guard options.experimental.enableMetrics else { return nil }

        self.scopeMetaData = SentryDefaultScopeApplyingMetadata(
            environment: options.environment,
            releaseName: options.releaseName,
            cacheDirectoryPath: options.cacheDirectoryPath,
            sendDefaultPii: options.sendDefaultPii
        )

        self.metricsBuffer = metricsBuffer
        self.beforeSendMetric = options.experimental.beforeSendMetric

        super.init()
    }

    func uninstall() {
        metricsBuffer.captureMetrics()
    }

    static var name: String {
        "SentryMetricsIntegration"
    }

    // MARK: - Public API for Metrics

    func addMetric(_ metric: SentryMetric, scope: Scope) {
        var mutableMetric = metric
        scope.addAttributesToItem(&mutableMetric, metadata: self.scopeMetaData)

        // The before send item closure can be used to drop metrics by returning nil
        // In case it is nil, we can discard the metric here
        if let beforeSendMetric = beforeSendMetric {
            // If the before send hook returns nil, the item should be dropped
            guard let processedItem = beforeSendMetric(mutableMetric) else {
                return
            }
            mutableMetric = processedItem
        }

        metricsBuffer.addMetric(mutableMetric)
    }

    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture metrics in seconds
    ///
    /// - Note: This method calls captureMetrics() on the internal buffer synchronously.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally.
    @discardableResult func captureMetrics() -> TimeInterval {
        return metricsBuffer.captureMetrics()
    }

    // MARK: - FlushableIntegration

    /// Flushes any buffered metrics synchronously.
    ///
    /// - Returns: The time taken to flush in seconds
    ///
    /// This method is called by SentryHub.flush() via respondsToSelector: check.
    /// We implement it directly in the class body (not in an extension) because
    /// extensions of generic classes cannot contain @objc members.
    /// The @objc attribute is required so Objective-C code can find this method
    /// via respondsToSelector: at runtime.
    @objc func flush() -> TimeInterval {
        return captureMetrics()
    }
    
}
