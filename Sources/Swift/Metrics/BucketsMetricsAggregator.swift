@_implementationOnly import _SentryPrivate

/// The bucket timestamp is calculated:
///     ( timeIntervalSince1970 / ROLLUP_IN_SECONDS ) * ROLLUP_IN_SECONDS
typealias BucketTimestamp = UInt64
let ROLLUP_IN_SECONDS: TimeInterval = 10

extension SentryCurrentDateProvider {
    var bucketTimestamp: BucketTimestamp {
        let now = self.date()
        let seconds = now.timeIntervalSince1970

        return (UInt64(seconds) / UInt64(ROLLUP_IN_SECONDS)) * UInt64(ROLLUP_IN_SECONDS)
    }
}

class BucketMetricsAggregator: MetricsAggregator {

    private let client: SentryMetricsClient
    private let currentDate: SentryCurrentDateProvider
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let random: SentryRandomProtocol
    private let totalMaxWeight: UInt
    private let flushShift: TimeInterval
    private let flushInterval: TimeInterval
    private let flushTolerance: TimeInterval

    private var timer: DispatchSourceTimer?
    private var totalBucketsWeight: UInt = 0
    private var buckets: [BucketTimestamp: [String: Metric]] = [:]
    private let lock = NSLock()

    init(
        client: SentryMetricsClient,
        currentDate: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        random: SentryRandomProtocol,
        totalMaxWeight: UInt = 1_000,
        flushInterval: TimeInterval = 10.0,
        flushTolerance: TimeInterval = 0.5
    ) {
        self.client = client
        self.currentDate = currentDate
        self.dispatchQueue = dispatchQueue
        self.random = random

        // The aggregator shifts its flushing by up to an entire rollup window to
        // avoid multiple clients trampling on end of a 10 second window as all the
        // buckets are anchored to multiples of ROLLUP seconds. We randomize this
        // number once per aggregator boot to achieve some level of offsetting
        // across a fleet of deployed SDKs.
        let flushShift = random.nextNumber() * ROLLUP_IN_SECONDS
        self.totalMaxWeight = totalMaxWeight
        self.flushInterval = flushInterval
        self.flushShift = flushShift
        self.flushTolerance = flushTolerance

        startTimer()
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(flags: [], queue: dispatchQueue.queue)

        // Set leeway to reduce energy impact
        let leewayInMilliseconds: Int = Int(flushTolerance * 1_000)
        timer.schedule(deadline: .now() + flushInterval, repeating: self.flushInterval, leeway: .milliseconds(leewayInMilliseconds))
        timer.setEventHandler { [weak self] in
            self?.flush(force: false)
        }
        timer.activate()
        self.timer = timer
    }
    
    func add(type: MetricType, key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator? = nil) {

        let tagsKey = getTagsKey(tags: tags)
        let bucketKey = "\(type)_\(key)_\(unit.unit)_\(tagsKey)"

        let bucketTimestamp = currentDate.bucketTimestamp

        var isOverWeight = false

        lock.synchronized {
            var bucket = buckets[bucketTimestamp] ?? [:]
            let oldWeight = bucket[bucketKey]?.weight ?? 0
            
            let metric = bucket[bucketKey] ?? initMetric(first: value, type: type, key: key, unit: unit, tags: tags)
            let metricExists = bucket[bucketKey] != nil
            
            if metricExists {
                metric.add(value: value)
            }
            
            let addedWeight = metric.weight - oldWeight

            bucket[bucketKey] = metric
            totalBucketsWeight += addedWeight

            buckets[bucketTimestamp] = bucket

            let totalWeight = UInt(buckets.count) + totalBucketsWeight
            isOverWeight = totalWeight >= totalMaxWeight
            
            // For sets, we only record that a value has been added to the set but not which one. See develop docs: https://develop.sentry.dev/sdk/metrics/#sets
            if localMetricsAggregator != nil {
                let localValue = type == .set ? Double(addedWeight) : value
                localMetricsAggregator?.add(type: type, key: key, value: localValue, unit: unit, tags: tags)
            }
        }

        if isOverWeight {
            dispatchQueue.dispatchAsync({ [weak self] in
                self?.flush(force: true)
            })
        }
    }
    
    private func initMetric(first: Double, type: MetricType, key: String, unit: MeasurementUnit, tags: [String: String]) -> Metric {
        switch type {
        case .counter:
            return CounterMetric(first: first, key: key, unit: unit, tags: tags)
        case .gauge:
            return GaugeMetric(first: first, key: key, unit: unit, tags: tags)
        case .distribution:
            return DistributionMetric(first: first, key: key, unit: unit, tags: tags)
        case .set:
            return SetMetric(first: Int32(first), key: key, unit: unit, tags: tags)
        }
    }

    func flush(force: Bool) {
        var flushableBuckets: [BucketTimestamp: [Metric]] = [:]

        if force {
            lock.synchronized {
                for (timestamp, metrics) in buckets {
                    flushableBuckets[timestamp] = Array(metrics.values)
                }

                buckets.removeAll()
                totalBucketsWeight = 0
            }
        } else {
            let cutoff = BucketTimestamp(currentDate.date().timeIntervalSince1970 - ROLLUP_IN_SECONDS - flushShift)

            lock.synchronized {
                for (bucketTimestamp, bucket) in buckets {
                    if bucketTimestamp <= cutoff {
                        flushableBuckets[bucketTimestamp] = Array(bucket.values)
                    }
                }

                var weightToRemove: UInt = 0
                for (bucketTimestamp, metrics) in flushableBuckets {
                    for metric in metrics {
                        weightToRemove += metric.weight
                    }
                    buckets.removeValue(forKey: bucketTimestamp)
                }

                totalBucketsWeight -= weightToRemove
            }
        }

        if !flushableBuckets.isEmpty {
            client.capture(flushableBuckets: flushableBuckets)
        }
    }

    func close() {
        self.flush(force: true)

        cancelTimer()
    }

    deinit {
        cancelTimer()
    }

    private func cancelTimer() {
        self.timer?.cancel()
        self.timer = nil
    }
}
