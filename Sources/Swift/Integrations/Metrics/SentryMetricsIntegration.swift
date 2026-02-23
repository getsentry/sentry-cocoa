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
    private let metricsBuffer: any TelemetryBuffer<SentryMetric>
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

        let metricsBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryMetric>, SentryMetric>(
            config: .init(
                flushTimeout: 5,
                maxItemCount: 100,
                maxBufferSizeBytes: 1_024 * 1_024,
                capturedDataCallback: { data, count in
                    let hub = SentrySDKInternal.currentHub()
                    guard let client = hub.getClient() else {
                        SentrySDKLog.debug("MetricsIntegration: No client available, dropping metrics")
                        return
                    }
                    client.captureMetricsData(data, with: NSNumber(value: count))
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dependencies.dateProvider,
            dispatchQueue: dependencies.dispatchQueueWrapper,
            itemForwardingTriggers: itemForwardingTriggers
        )

        self.init(with: options, dependencies: dependencies, metricsBuffer: metricsBuffer)
    }

    /// Initializer for testing that allows injecting a custom metrics buffer
    init?(with options: Options, dependencies: Dependencies, metricsBuffer: any TelemetryBuffer<SentryMetric>) {
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
        _ = metricsBuffer.capture()
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

        metricsBuffer.add(mutableMetric)
    }

    /// Captures batched metrics synchronously and returns the duration.
    @discardableResult func captureMetrics() -> TimeInterval {
        return metricsBuffer.capture()
    }

    // MARK: - FlushableIntegration

    /// Flushes any buffered metrics synchronously.
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
