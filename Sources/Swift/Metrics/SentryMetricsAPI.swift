@_implementationOnly import _SentryPrivate
import Foundation

@objc protocol SentryMetricsAPIDelegate: AnyObject {
    func getDefaultTagsForMetrics() -> [String: String]
    
    func getLocalMetricsAggregator() -> LocalMetricsAggregator?
}

@objc public class SentryMetricsAPI: NSObject {

    private let aggregator: MetricsAggregator
    
    private weak var delegate: SentryMetricsAPIDelegate?

    @objc init(enabled: Bool, client: SentryMetricsClient, currentDate: SentryCurrentDateProvider, dispatchQueue: SentryDispatchQueueWrapper, random: SentryRandomProtocol) {
        
        if enabled {
            self.aggregator = BucketMetricsAggregator(client: client, currentDate: currentDate, dispatchQueue: dispatchQueue, random: random)
        } else {
            self.aggregator = NoOpMetricsAggregator()
        }
    }
    
    @objc func setDelegate(_ delegate: SentryMetricsAPIDelegate?) {
        self.delegate = delegate
    }
    
    /// Emits a Counter metric.
    ///
    /// - Parameter key: A unique key identifying the metric.
    /// - Parameter value: The value to be added.
    /// - Parameter unit: The value for the metric see `MeasurementUnit`.
    /// - Parameter tags: Tags to associate with the metric.
    @objc public func increment(key: String, value: Double = 1.0, unit: MeasurementUnit = .none, tags: [String: String] = [:]) {
        let mergedTags = mergeDefaultTagsInto(tags: tags)
        aggregator.add(type: MetricType.counter, key: key, value: value, unit: unit, tags: mergedTags, localMetricsAggregator: delegate?.getLocalMetricsAggregator())
    }
    
    /// Emits a Gauge metric.
    ///
    /// - Parameter key: A unique key identifying the metric.
    /// - Parameter value: The value to be added.
    /// - Parameter unit: The value for the metric see `MeasurementUnit`.
    /// - Parameter tags: Tags to associate with the metric.
    @objc
    public func gauge(key: String, value: Double, unit: MeasurementUnit = .none, tags: [String: String] = [:]) {
        let mergedTags = mergeDefaultTagsInto(tags: tags)
        aggregator.add(type: MetricType.gauge, key: key, value: value, unit: unit, tags: mergedTags, localMetricsAggregator: delegate?.getLocalMetricsAggregator())
    }
    
    /// Emits a Distribution metric.
    ///
    /// - Parameter key: A unique key identifying the metric.
    /// - Parameter value: The value to be added.
    /// - Parameter unit: The value for the metric see `MeasurementUnit`.
    /// - Parameter tags: Tags to associate with the metric.
    @objc
    public func distribution(key: String, value: Double, unit: MeasurementUnit = .none, tags: [String: String] = [:]) {
        let mergedTags = mergeDefaultTagsInto(tags: tags)
        aggregator.add(type: MetricType.distribution, key: key, value: value, unit: unit, tags: mergedTags, localMetricsAggregator: delegate?.getLocalMetricsAggregator())
    }
    
    /// Emits a Set metric.
    ///
    /// - Parameter key: A unique key identifying the metric.
    /// - Parameter value: The value to be added.
    /// - Parameter unit: The value for the metric see `MeasurementUnit`.
    /// - Parameter tags: Tags to associate with the metric.
    @objc
    public func set(key: String, value: String, unit: MeasurementUnit = .none, tags: [String: String] = [:]) {
        let mergedTags = mergeDefaultTagsInto(tags: tags)
    
        let crc32 = sentry_crc32ofString(value)
        
        aggregator.add(type: MetricType.set, key: key, value: Double(crc32), unit: unit, tags: mergedTags, localMetricsAggregator: delegate?.getLocalMetricsAggregator())
    }

    @objc public func close() {
        aggregator.close()
        delegate = nil
    }
    
    @objc public func flush() {
        aggregator.flush(force: true)
    }
    
    /// Merges the default tags into the passed tags. If there are duplicates the method keeps the passed in tags and discards the default tags.
    private func mergeDefaultTagsInto(tags: [String: String]) -> [String: String] {
        let defaultTags = delegate?.getDefaultTagsForMetrics() ?? [:]
        return tags.merging(defaultTags) { (tagValue, _) in tagValue }
    }

}
