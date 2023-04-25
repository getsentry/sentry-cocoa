#import "SentryMetricProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCurrentDate.h"
#    import "SentryDispatchFactory.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryDispatchSourceWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryLog.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryNSTimerWrapper.h"
#    import "SentrySystemWrapper.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"

/**
 * A storage class for metric readings, with one property for the reading value itself, whether it
 * be bytes of memory, % CPU etc, and another for the absolute system time it was recorded at.
 */
@interface SentryMetricReading : NSObject
@property (strong, nonatomic) NSNumber *value;
@property (assign, nonatomic) uint64_t absoluteTimestamp;
@end
@implementation SentryMetricReading
@end

NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint = @"memory_footprint";
NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat = @"cpu_usage_%d";

NSString *const kSentryMetricProfilerSerializationUnitBytes = @"byte";
NSString *const kSentryMetricProfilerSerializationUnitPercentage = @"percent";

// Currently set to 10 Hz as we don't anticipate much utility out of a higher resolution when
// sampling CPU usage and memory footprint, and we want to minimize the overhead of making the
// necessary system calls to gather that information. This is currently roughly 10% of the
// backtrace profiler's resolution.
static uint64_t frequencyHz = 10;
static uint64_t leewayNs = 50000; // 50 milliseconds

namespace {
/**
 * @return a dictionary containing all the metric values recorded during the transaction, or @c nil
 * if there were no metrics recorded during the transaction.
 */
SentrySerializedMetricEntry *_Nullable serializeValuesWithNormalizedTime(
    NSArray<SentryMetricReading *> *absoluteTimestampValues, NSString *unit,
    SentryTransaction *transaction)
{
    const auto *timestampNormalizedValues = [NSMutableArray<SentrySerializedMetricReading *> array];
    [absoluteTimestampValues enumerateObjectsUsingBlock:^(
        SentryMetricReading *_Nonnull reading, NSUInteger idx, BOOL *_Nonnull stop) {
        // if the metric reading wasn't recorded until the transaction ended, don't include it
        if (!orderedChronologically(reading.absoluteTimestamp, transaction.endSystemTime)) {
            return;
        }

        // if the metric reading was taken before the transaction started, don't include it
        if (!orderedChronologically(transaction.startSystemTime, reading.absoluteTimestamp)) {
            return;
        }

        const auto relativeTimestamp
            = getDurationNs(transaction.startSystemTime, reading.absoluteTimestamp);

        [timestampNormalizedValues addObject:@{
            @"elapsed_since_start_ns" : @(relativeTimestamp).stringValue,
            @"value" : reading.value
        }];
    }];
    if (timestampNormalizedValues.count == 0) {
        return nil;
    }
    return @ { @"unit" : unit, @"values" : timestampNormalizedValues };
}
} // namespace

@implementation SentryMetricProfiler {
    SentryDispatchSourceWrapper *_timer;

    SentryNSProcessInfoWrapper *_processInfoWrapper;
    SentrySystemWrapper *_systemWrapper;
    SentryDispatchFactory *_dispatchFactory;

    /// arrays of readings keyed on NSNumbers representing the core number for the set of readings
    NSMutableDictionary<NSNumber *, NSMutableArray<SentryMetricReading *> *> *_cpuUsage;

    NSMutableArray<SentryMetricReading *> *_memoryFootprint;
}

- (instancetype)initWithProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
                             systemWrapper:(SentrySystemWrapper *)systemWrapper
                           dispatchFactory:(nonnull SentryDispatchFactory *)dispatchFactory
{
    if (self = [super init]) {
        _cpuUsage =
            [NSMutableDictionary<NSNumber *, NSMutableArray<SentryMetricReading *> *> dictionary];
        const auto processorCount = processInfoWrapper.processorCount;
        SENTRY_LOG_DEBUG(
            @"Preparing %lu arrays for CPU core usage readings", (long unsigned)processorCount);
        for (NSUInteger core = 0; core < processorCount; core++) {
            _cpuUsage[@(core)] = [NSMutableArray<SentryMetricReading *> array];
        }

        _systemWrapper = systemWrapper;
        _processInfoWrapper = processInfoWrapper;
        _dispatchFactory = dispatchFactory;

        _memoryFootprint = [NSMutableArray<SentryMetricReading *> array];
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

- (void)stop
{
    [_timer cancel];
}

- (NSMutableDictionary<NSString *, id> *)serializeForTransaction:(SentryTransaction *)transaction
{
    NSMutableDictionary<NSString *, id> *dict;
    @synchronized(self) {
        dict = [NSMutableDictionary<NSString *, id> dictionary];
    }

    if (_memoryFootprint.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryFootprint]
            = serializeValuesWithNormalizedTime(
                _memoryFootprint, kSentryMetricProfilerSerializationUnitBytes, transaction);
    }

    [_cpuUsage enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull core,
        NSMutableArray<SentryMetricReading *> *_Nonnull readings, BOOL *_Nonnull stop) {
        if (readings.count > 0) {
            dict[[NSString stringWithFormat:kSentryMetricProfilerSerializationKeyCPUUsageFormat,
                           core.intValue]]
                = serializeValuesWithNormalizedTime(
                    readings, kSentryMetricProfilerSerializationUnitPercentage, transaction);
        }
    }];

    return dict;
}

#    pragma mark - Private

- (void)registerSampler
{
    __weak auto weakSelf = self;
    _timer =
        [_dispatchFactory sourceWithInterval:intervalNs
                                      leeway:(uint64_t)1e9 / frequencyHz
                                   queueName:"io.sentry.metric-profiler"
                                  attributes:dispatch_queue_attr_make_with_qos_class(
                                                 DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0)
                                eventHandler:^{
                                    [weakSelf recordCPUPercentagePerCore];
                                    [weakSelf recordMemoryFootprint];
                                }];
}

- (void)recordMemoryFootprint
{
    NSError *error;
    const auto footprintBytes = [_systemWrapper memoryFootprintBytes:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Failed to read memory footprint: %@", error);
        return;
    }

    @synchronized(self) {
        [_memoryFootprint addObject:[self metricReadingForValue:@(footprintBytes)]];
    }
}

- (void)recordCPUPercentagePerCore
{
    NSError *error;
    const auto result = [_systemWrapper cpuUsagePerCore:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Failed to read CPU usages: %@", error);
        return;
    }

    @synchronized(self) {
        [result enumerateObjectsUsingBlock:^(
            NSNumber *_Nonnull usage, NSUInteger core, BOOL *_Nonnull stop) {
            [_cpuUsage[@(core)] addObject:[self metricReadingForValue:usage]];
        }];
    }
}

- (SentryMetricReading *)metricReadingForValue:(NSNumber *)value
{
    const auto reading = [[SentryMetricReading alloc] init];
    reading.value = value;
    reading.absoluteTimestamp = SentryCurrentDate.systemTime;
    return reading;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
