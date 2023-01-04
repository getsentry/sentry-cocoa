#import "SentryMetricProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryLog.h"
#    import "SentryMachLogging.hpp"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryNSTimerWrapper.h"
#    import "SentrySystemWrapper.h"
#    import "SentryTime.h"

/**
 * Currently set to 10 Hz as we don't anticipate much utility out of a higher resolution when
 * sampling CPU usage and memory footprint, and we want to minimize the overhead of making the
 * necessary system calls to gather that information.
 */
static const NSTimeInterval kSentryMetricProfilerTimeseriesInterval = 0.1;

NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint = @"memory_footprint";
NSString *const kSentryMetricProfilerSerializationKeyMemoryPressure = @"memory_pressure";
NSString *const kSentryMetricProfilerSerializationKeyPowerState = @"is_low_power_mode";
NSString *const kSentryMetricProfilerSerializationKeyThermalState = @"thermal_state";
NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat = @"cpu_usage_%d";

NSString *const kSentryMetricProfilerSerializationUnitBytes = @"byte";
NSString *const kSentryMetricProfilerSerializationUnitBoolean = @"bool";
NSString *const kSentryMetricProfilerSerializationUnitMemoryPressureEnum = @"memory_pressure_enum";
NSString *const kSentryMetricProfilerSerializationUnitThermalStateEnum = @"thermal_state_enum";
NSString *const kSentryMetricProfilerSerializationUnitPercentage = @"percent";

namespace {
NSDictionary<NSString *, id> *
serializedValues(NSArray<NSDictionary<NSString *, NSString *> *> *values, NSString *unit)
{
    return @ { @"unit" : unit, @"values" : values };
}
} // namespace

@implementation SentryMetricProfiler {
    NSTimer *_timer;

    SentryNSProcessInfoWrapper *_processInfoWrapper;
    SentrySystemWrapper *_systemWrapper;
    SentryNSTimerWrapper *_timerWrapper;

    /// arrays of readings keyed on NSNumbers representing the core number for the set of readings
    NSMutableDictionary<NSNumber *, NSMutableArray<NSDictionary<NSString *, NSString *> *> *>
        *_cpuUsage;

    NSMutableArray<NSDictionary<NSString *, id> *> *_memoryFootprint;
    NSMutableArray<NSDictionary<NSString *, id> *> *_thermalState;
    NSMutableArray<NSDictionary<NSString *, id> *> *_powerLevelState;
    NSMutableArray<NSDictionary<NSString *, id> *> *_memoryPressureState;
    uint64_t _profileStartTime;
}

- (instancetype)initWithProfileStartTime:(uint64_t)profileStartTime
                      processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
                           systemWrapper:(SentrySystemWrapper *)systemWrapper
                            timerWrapper:(SentryNSTimerWrapper *)timerWrapper
{
    if (self = [super init]) {
        _cpuUsage = [NSMutableDictionary<NSNumber *,
            NSMutableArray<NSDictionary<NSString *, NSString *> *> *>
            dictionary];
        const auto processorCount = processInfoWrapper.processorCount;
        SENTRY_LOG_DEBUG(
            @"Preparing %lu arrays for CPU core usage readings", (long unsigned)processorCount);
        for (NSUInteger core = 0; core < processorCount; core++) {
            _cpuUsage[@(core)] = [NSMutableArray<NSDictionary<NSString *, NSString *> *> array];
        }

        _systemWrapper = systemWrapper;
        _processInfoWrapper = processInfoWrapper;
        _timerWrapper = timerWrapper;

        _memoryFootprint = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        _thermalState = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        _powerLevelState = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        _memoryPressureState = [NSMutableArray<NSDictionary<NSString *, id> *> array];

        _profileStartTime = profileStartTime;
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
    [self registerStateChangeNotifications];
    [self registerMemoryPressureWarningHandler];
}

- (void)stop
{
    [_timer invalidate];
    [_systemWrapper deregisterMemoryPressureNotifications];
    [_processInfoWrapper stopMonitoring:self];
}

- (NSMutableDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *dict;
    @synchronized(self) {
        dict = [NSMutableDictionary<NSString *, id> dictionary];
    }

    if (_memoryFootprint.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryFootprint]
            = serializedValues(_memoryFootprint, kSentryMetricProfilerSerializationUnitBytes);
    }
    if (_memoryPressureState.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryPressure] = serializedValues(
            _memoryPressureState, kSentryMetricProfilerSerializationUnitMemoryPressureEnum);
    }
    if (_powerLevelState.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyPowerState]
            = serializedValues(_powerLevelState, kSentryMetricProfilerSerializationUnitBoolean);
    }
    if (_thermalState.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyThermalState] = serializedValues(
            _thermalState, kSentryMetricProfilerSerializationUnitThermalStateEnum);
    }

    [_cpuUsage enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull core,
        NSMutableArray<NSDictionary<NSString *, NSString *> *> *_Nonnull readings,
        BOOL *_Nonnull stop) {
        if (readings.count > 0) {
            dict[[NSString stringWithFormat:kSentryMetricProfilerSerializationKeyCPUUsageFormat,
                           core.intValue]]
                = serializedValues(readings, kSentryMetricProfilerSerializationUnitPercentage);
        }
    }];

    return dict;
}

#    pragma mark - Private

- (void)registerSampler
{
    __weak auto weakSelf = self;
    _timer = [_timerWrapper scheduledTimerWithTimeInterval:kSentryMetricProfilerTimeseriesInterval
                                                   repeats:YES
                                                     block:^(NSTimer *_Nonnull timer) {
                                                         [weakSelf recordCPUPercentagePerCore];
                                                         [weakSelf recordMemoryFootprint];
                                                     }];
}

/**
 * This is a more fine-grained API, providing normal/warn/critical levels of memory usage, versus
 * using `UIApplicationDidReceiveMemoryWarningNotification` which does not provide any additional
 * information ("This notification does not contain a userInfo dictionary." from
 * https://developer.apple.com/documentation/uikit/uiapplication/1622920-didreceivememorywarningnotificat).
 */
- (void)registerMemoryPressureWarningHandler
{
    __weak auto weakSelf = self;
    [_systemWrapper registerMemoryPressureNotifications:^(uintptr_t memoryPressureState) {
        const auto strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @synchronized(strongSelf) {
            [strongSelf->_memoryPressureState
                addObject:[strongSelf metricEntryForValue:@(memoryPressureState)]];
        }
    }];
}

- (void)registerStateChangeNotifications
{
    // According to Apple docs: "To receive NSProcessInfoThermalStateDidChangeNotification, you must
    // access the thermalState prior to registering for the notification." (from
    // https://developer.apple.com/documentation/foundation/nsprocessinfothermalstatedidchangenotification/)
    [self recordThermalState];

    [_processInfoWrapper monitorForThermalStateChanges:self callback:@selector(recordThermalState)];

    if (@available(macOS 12.0, *)) {
        [_processInfoWrapper monitorForPowerStateChanges:self
                                                callback:@selector(recordPowerLevelState)];
    }
}

- (void)recordThermalState
{
    @synchronized(self) {
        [_thermalState addObject:[self metricEntryForValue:@(_processInfoWrapper.thermalState)]];
    }
}

- (void)recordPowerLevelState
{
    if (@available(macOS 12.0, *)) {
        @synchronized(self) {
            [_powerLevelState
                addObject:[self metricEntryForValue:@(_processInfoWrapper.isLowPowerModeEnabled
                                                            ? 1.f
                                                            : 0.f)]];
        }
    }
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
        [_memoryFootprint addObject:[self metricEntryForValue:@(footprintBytes)]];
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
            [_cpuUsage[@(core)] addObject:[self metricEntryForValue:usage]];
        }];
    }
}

- (NSDictionary<NSString *, id> *)metricEntryForValue:(NSNumber *)value
{
    return @{
        @"value" : value,
        @"elapsed_since_start_ns" :
            [@(getDurationNs(_profileStartTime, getAbsoluteTime())) stringValue]
    };
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
