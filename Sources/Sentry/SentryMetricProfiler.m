#import "SentryMetricProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryFormatter.h"
#    import "SentryLogC.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryTime.h"

/**
 * A storage class for metric readings, with one property for the reading value itself, whether it
 * be bytes of memory, % CPU etc, and another for the absolute system time it was recorded at.
 */
@interface SentryMetricReading : NSObject
@property (strong, nonatomic) NSNumber *value;
@property (assign, nonatomic) uint64_t absoluteSystemTimestamp;
@property (assign, nonatomic) NSTimeInterval absoluteNSDateInterval;
@end
@implementation SentryMetricReading
@end

NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint = @"memory_footprint";
NSString *const kSentryMetricProfilerSerializationKeyCPUUsage = @"cpu_usage";
NSString *const kSentryMetricProfilerSerializationKeyCPUEnergyUsage = @"cpu_energy_usage";

NSString *const kSentryMetricProfilerSerializationUnitBytes = @"byte";
NSString *const kSentryMetricProfilerSerializationUnitPercentage = @"percent";
NSString *const kSentryMetricProfilerSerializationUnitNanoJoules = @"nanojoule";

// Currently set to 10 Hz as we don't anticipate much utility out of a higher resolution when
// sampling CPU usage and memory footprint, and we want to minimize the overhead of making the
// necessary system calls to gather that information. This is currently roughly 10% of the
// backtrace profiler's resolution.
static NSInteger frequencyHz = 10;

/**
 * @return a dictionary containing all the metric values recorded during the transaction, or @c nil
 * if there were no metrics recorded during the transaction.
 */
SentrySerializedMetricEntry *_Nullable serializeTraceProfileMetricValuesWithNormalizedTime(
    NSArray<SentryMetricReading *> *absoluteTimestampValues, NSString *unit,
    uint64_t startSystemTime, uint64_t endSystemTime)
{
    NSMutableArray<SentrySerializedMetricReading *> *timestampNormalizedValues =
        [NSMutableArray<SentrySerializedMetricReading *> array];
    [absoluteTimestampValues enumerateObjectsUsingBlock:^(
        SentryMetricReading *_Nonnull reading, NSUInteger idx, BOOL *_Nonnull stop) {
        // if the metric reading wasn't recorded until the transaction ended, don't include it
        if (!orderedChronologically(reading.absoluteSystemTimestamp, endSystemTime)) {
            return;
        }

        // if the metric reading was taken before the transaction started, don't include it
        if (!orderedChronologically(startSystemTime, reading.absoluteSystemTimestamp)) {
            return;
        }

        NSMutableDictionary *value = [NSMutableDictionary dictionary];
        uint64_t relativeTimestamp
            = getDurationNs(startSystemTime, reading.absoluteSystemTimestamp);
        value[@"elapsed_since_start_ns"] = sentry_stringForUInt64(relativeTimestamp);
        value[@"value"] = reading.value;
        [timestampNormalizedValues addObject:value];
    }];
    if (timestampNormalizedValues.count == 0) {
        return nil;
    }
    return @ { @"unit" : unit, @"values" : timestampNormalizedValues };
}

/**
 * @return a dictionary containing all the metric values recorded during the continuous profile with
 * absolute timestamps, or @c nil if there were no metrics recorded
 */
SentrySerializedMetricEntry *_Nullable serializeContinuousProfileMetricReadings(
    NSArray<SentryMetricReading *> *readings, NSString *unit)
{
    if (readings.count == 0) {
        return nil;
    }
    NSMutableArray<SentrySerializedMetricReading *> *serializedValues =
        [NSMutableArray<SentrySerializedMetricReading *> array];
    [readings enumerateObjectsUsingBlock:^(
        SentryMetricReading *_Nonnull reading, NSUInteger idx, BOOL *_Nonnull stop) {
        NSMutableDictionary *value = [NSMutableDictionary dictionary];
        value[@"timestamp"] = @(reading.absoluteNSDateInterval);
        value[@"value"] = reading.value;
        [serializedValues addObject:value];
    }];
    return @ { @"unit" : unit, @"values" : serializedValues };
}

NSDictionary<NSString *, id> *
serializeContinuousProfileMetrics(NSDictionary *state)
{
    NSMutableDictionary<NSString *, id> *dict = [NSMutableDictionary<NSString *, id> dictionary];
    NSArray<SentryMetricReading *> *memoryFootprint
        = state[kSentryMetricProfilerSerializationKeyMemoryFootprint];
    if (memoryFootprint.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryFootprint]
            = serializeContinuousProfileMetricReadings(
                memoryFootprint, kSentryMetricProfilerSerializationUnitBytes);
    }
    NSArray<SentryMetricReading *> *cpuEnergyUsage
        = state[kSentryMetricProfilerSerializationKeyCPUEnergyUsage];
    if (cpuEnergyUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUEnergyUsage]
            = serializeContinuousProfileMetricReadings(
                cpuEnergyUsage, kSentryMetricProfilerSerializationUnitNanoJoules);
    }

    NSArray<SentryMetricReading *> *cpuUsage = state[kSentryMetricProfilerSerializationKeyCPUUsage];
    if (cpuUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUUsage]
            = serializeContinuousProfileMetricReadings(
                cpuUsage, kSentryMetricProfilerSerializationUnitPercentage);
    }

    return dict;
}

@implementation SentryMetricProfiler {
    id<SentryProfilingCancellation> _sampling;

    NSMutableArray<SentryMetricReading *> *_cpuUsage;
    NSMutableArray<SentryMetricReading *> *_memoryFootprint;

    NSNumber *previousEnergyReading;
    NSMutableArray<SentryMetricReading *> *_cpuEnergyUsage;

    SentryProfilerMode _mode;
}

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (self = [super init]) {
        // It doesn't make sense to acquire a lock in the init.
        [self clearNotThreadSafe];
        _mode = mode;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#    pragma mark - Public

- (void)start
{
    [self registerSampler];
}

- (void)recordMetrics
{
    SentryProfilingSystemMetrics *metrics = [SentryProfilerSDKAdapter.shared systemMetrics];
    [self recordCPUsage:metrics.cpuUsage];
    [self recordMemoryFootprint:metrics.memoryFootprintBytes];
#    if defined(__arm__) || defined(__arm64__)
    [self recordEnergyUsageEstimate:metrics.cpuEnergyUsage];
#    endif
}

- (void)stop
{
    [_sampling cancel];
}

- (NSMutableDictionary<NSString *, id> *)
    serializeTraceProfileMetricsBetween:(uint64_t)startSystemTime
                                    and:(uint64_t)endSystemTime;
{
    NSArray<SentryMetricReading *> *memoryFootprint;
    NSArray<SentryMetricReading *> *cpuEnergyUsage;
    NSArray<SentryMetricReading *> *cpuUsage;
    @synchronized(self) {
        cpuEnergyUsage = [NSArray<SentryMetricReading *> arrayWithArray:_cpuEnergyUsage];
        memoryFootprint = [NSArray<SentryMetricReading *> arrayWithArray:_memoryFootprint];
        cpuUsage = [NSArray<SentryMetricReading *> arrayWithArray:_cpuUsage];
    }

    NSMutableDictionary<NSString *, id> *dict = [NSMutableDictionary<NSString *, id> dictionary];
    if (memoryFootprint.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryFootprint]
            = serializeTraceProfileMetricValuesWithNormalizedTime(memoryFootprint,
                kSentryMetricProfilerSerializationUnitBytes, startSystemTime, endSystemTime);
    }
    if (cpuEnergyUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUEnergyUsage]
            = serializeTraceProfileMetricValuesWithNormalizedTime(cpuEnergyUsage,
                kSentryMetricProfilerSerializationUnitNanoJoules, startSystemTime, endSystemTime);
    }

    if (cpuUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUUsage]
            = serializeTraceProfileMetricValuesWithNormalizedTime(cpuUsage,
                kSentryMetricProfilerSerializationUnitPercentage, startSystemTime, endSystemTime);
    }

    return dict;
}

- (NSDictionary<NSString *, NSArray<SentryMetricReading *> *> *)copyMetricProfilerData
{
    NSMutableDictionary *copy = [NSMutableDictionary dictionary];
    @synchronized(self) {
        copy[kSentryMetricProfilerSerializationKeyMemoryFootprint] = [_memoryFootprint copy];
        copy[kSentryMetricProfilerSerializationKeyCPUUsage] = [_cpuUsage copy];
        copy[kSentryMetricProfilerSerializationKeyCPUEnergyUsage] = [_cpuEnergyUsage copy];
    }
    return copy;
}

- (void)clear
{
    @synchronized(self) {
        [self clearNotThreadSafe];
    }
}

- (void)clearNotThreadSafe
{
    _cpuUsage = [NSMutableArray<SentryMetricReading *> array];
    _memoryFootprint = [NSMutableArray<SentryMetricReading *> array];
    _cpuEnergyUsage = [NSMutableArray<SentryMetricReading *> array];
}

#    pragma mark - Private

- (void)registerSampler
{
    __weak typeof(self) weakSelf = self;
    NSInteger intervalNs = (NSInteger)1e9 / frequencyHz;
    NSInteger leewayNs = intervalNs / 2;
    _sampling = [SentryProfilerSDKAdapter.shared
        scheduleMetricSamplingWithInterval:intervalNs
                                    leeway:leewayNs
                                     block:^{ [weakSelf recordMetrics]; }];
}

- (void)recordMemoryFootprint:(NSNumber *_Nullable)footprintBytes
{
    if (footprintBytes == nil) {
        return;
    }

    @synchronized(self) {
        [_memoryFootprint addObject:[self metricReadingForValue:footprintBytes]];
    }
}

- (void)recordCPUsage:(NSNumber *_Nullable)result
{
    if (result == nil) {
        return;
    }

    @synchronized(self) {
        [_cpuUsage addObject:[self metricReadingForValue:result]];
    }
}

// Only some architectures support reading energy.
#    if defined(__arm__) || defined(__arm64__)
- (void)recordEnergyUsageEstimate:(NSNumber *_Nullable)reading
{
    if (reading == nil) {
        return;
    }

    if (previousEnergyReading == nil) {
        previousEnergyReading = reading;
        return;
    }

    NSUInteger value = reading.unsignedIntegerValue - previousEnergyReading.unsignedIntegerValue;
    previousEnergyReading = reading;

    @synchronized(self) {
        [_cpuEnergyUsage addObject:[self metricReadingForValue:@(value)]];
    }
}
#    endif

- (SentryMetricReading *)metricReadingForValue:(NSNumber *)value
{
    SentryMetricReading *reading = [[SentryMetricReading alloc] init];
    reading.value = value;
    SentryProfilingTimestamp timestamp = [SentryProfilerSDKAdapter.shared timestamp];
    reading.absoluteSystemTimestamp = timestamp.systemTime;
    reading.absoluteNSDateInterval = timestamp.dateInterval;
    return reading;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
