@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public protocol SentryMetricBatcherDelegate: AnyObject {
    @objc(captureMetricsData:with:)
    func capture(metricsData: NSData, count: NSNumber)
}

@objc
@objcMembers
@_spi(Private) public class SentryMetricBatcher: NSObject {
    
    private let options: Options
    private let flushTimeout: TimeInterval
    private let maxMetricCount: Int
    private let maxBufferSizeBytes: Int
    private let dispatchQueue: SentryDispatchQueueWrapper

    // All mutable state is accessed from the same serial dispatch queue.
    
    // Every metrics data is added separately. They are flushed together in an envelope.
    private var encodedMetrics: [Data] = []
    private var encodedMetricsSize: Int = 0
    private var timerWorkItem: DispatchWorkItem?
        
    weak var delegate: SentryMetricBatcherDelegate?
    
    /// Convenience initializer with default flush timeout, max metric count (100), and buffer size.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - delegate: The delegate to handle captured metric batches
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Setting `maxMetricCount` to 100. This matches the logs batcher limit.
    @_spi(Private) public convenience init(
        options: Options,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            options: options,
            flushTimeout: 5,
            maxMetricCount: 100, // Maximum 100 metrics per batch
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB buffer size
            dispatchQueue: dispatchQueue
        )
    }

    /// Initializes a new SentryMetricBatcher.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - flushTimeout: The timeout interval after which buffered metrics will be flushed
    ///   - maxMetricCount: Maximum number of metrics to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - delegate: The delegate to handle captured metric batches
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Metrics are flushed when either `maxMetricCount` or `maxBufferSizeBytes` limit is reached.
    @_spi(Private) public init(
        options: Options,
        flushTimeout: TimeInterval,
        maxMetricCount: Int,
        maxBufferSizeBytes: Int,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.options = options
        self.flushTimeout = flushTimeout
        self.maxMetricCount = maxMetricCount
        self.maxBufferSizeBytes = maxBufferSizeBytes
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    @_spi(Private) @objc public func addMetric(_ metric: SentryMetric, scope: Scope) {
        guard options.enableMetrics else {
            return
        }

        addDefaultAttributes(to: &metric.attributes, scope: scope)
        addReplayAttributes(to: &metric.attributes, scope: scope)
        addUserAttributes(to: &metric.attributes, scope: scope)
        addScopeAttributes(to: &metric.attributes, scope: scope)

        let propagationContextTraceIdString = scope.propagationContextTraceIdString
        metric.traceId = SentryId(uuidString: propagationContextTraceIdString)
        
        // Set span_id if there's an active span
        if let span = scope.span {
            metric.spanId = span.spanId
        }

        var processedMetric: SentryMetric? = metric
        if let beforeSendMetric = options.beforeSendMetric {
            processedMetric = beforeSendMetric(metric)
        }
        
        if let processedMetric {
            if options.debug {
                SentrySDKLog.debug("[SentryMetrics] \(processedMetric.type.stringValue): \(processedMetric.name) = \(processedMetric.value)")
            }
            dispatchQueue.dispatchAsync { [weak self] in
                self?.encodeAndBuffer(metric: processedMetric)
            }
        }
    }
    
    // Captures batched metrics sync and returns the duration.
    @discardableResult
    @_spi(Private) @objc public func captureMetrics() -> TimeInterval {
        let startTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureMetrics()
        }
        let endTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    // Helper

    private func addDefaultAttributes(to attributes: inout [String: SentryMetric.Attribute], scope: Scope) {
        attributes["sentry.sdk.name"] = .init(string: SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .init(string: SentryMeta.versionString)
        attributes["sentry.environment"] = .init(string: options.environment)
        if let releaseName = options.releaseName {
            attributes["sentry.release"] = .init(string: releaseName)
        }
        if let span = scope.span {
            attributes["sentry.trace.parent_span_id"] = .init(string: span.spanId.sentrySpanIdString)
        }
    }

    private func addReplayAttributes(to attributes: inout [String: SentryMetric.Attribute], scope: Scope) {
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        if let scopeReplayId = scope.replayId {
            // Session mode: use scope replay ID
            attributes["sentry.replay_id"] = .init(string: scopeReplayId)
        }
#endif
#endif
    }
    
    private func addUserAttributes(to attributes: inout [String: SentryMetric.Attribute], scope: Scope) {
        guard options.sendDefaultPii else {
            return
        }
        guard let user = scope.userObject else {
            return
        }
        if let userId = user.userId {
            attributes["user.id"] = .init(string: userId)
        }
        if let userName = user.name {
            attributes["user.name"] = .init(string: userName)
        }
        if let userEmail = user.email {
            attributes["user.email"] = .init(string: userEmail)
        }
    }
    
    private func addScopeAttributes(to attributes: inout [String: SentryMetric.Attribute], scope: Scope) {
        // Scope attributes should not override any existing attribute in the metric
        for (key, value) in scope.attributes where attributes[key] == nil {
            attributes[key] = .init(value: value)
        }
    }

    // Only ever call this from the serial dispatch queue.
    private func encodeAndBuffer(metric: SentryMetric) {
        do {
            let encodedMetric = try encodeToJSONData(data: metric)
            
            let encodedMetricsWereEmpty = encodedMetrics.isEmpty
            
            encodedMetrics.append(encodedMetric)
            encodedMetricsSize += encodedMetric.count
            
            // Flush when we reach max metric count or max buffer size
            if encodedMetrics.count >= maxMetricCount || encodedMetricsSize >= maxBufferSizeBytes {
                performCaptureMetrics()
            } else if encodedMetricsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode metric: \(error)")
        }
    }
    
    // Only ever call this from the serial dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("SentryMetricBatcher: Timer fired, calling performCaptureMetrics().")
            self?.performCaptureMetrics()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: flushTimeout, workItem: timerWorkItem)
    }

    // Only ever call this from the serial dispatch queue.
    private func performCaptureMetrics() {
        // Reset metrics on function exit
        defer {
            encodedMetrics.removeAll()
            encodedMetricsSize = 0
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil
        
        guard encodedMetrics.count > 0 else {
            SentrySDKLog.debug("SentryMetricBatcher: No metrics to flush.")
            return
        }

        // Create the payload.
        
        var payloadData = Data()
        payloadData.append(Data("{\"items\":[".utf8))
        let separator = Data(",".utf8)
        for (index, encodedMetric) in encodedMetrics.enumerated() {
            if index > 0 {
                payloadData.append(separator)
            }
            payloadData.append(encodedMetric)
        }
        payloadData.append(Data("]}".utf8))
        
        // Send the payload.
        
        if let delegate {
            delegate.capture(metricsData: payloadData as NSData, count: NSNumber(value: encodedMetrics.count))
        } else {
            SentrySDKLog.debug("SentryMetricBatcher: Delegate not set, not capturing metrics data.")
        }
    }
}
