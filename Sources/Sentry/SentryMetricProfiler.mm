#import "SentryMetricProfiler.h"
#import "SentryMachLogging.hpp"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentryTime.h"
#include <mach/mach.h>

const NSTimeInterval kSentryMetricProfilerInterval = 0.1; // 10 Hz

@implementation SentryMetricProfiler {
    NSTimer *_timer;
    SentryNSNotificationCenterWrapper *_notificationCenter;
    dispatch_source_t _memoryWarningSource;
    dispatch_queue_t _memoryWarningQueue;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *_cpuTimeSeries;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *_memoryFootprintTimeSeries;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *_thermalStateChanges;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *_powerLevelStateChanges;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *_memoryPressureStateChanges;
    uint64_t _profileStartTime;
}

- (instancetype)initWithNotificationCenterWrapper:
                    (SentryNSNotificationCenterWrapper *)notificationCenterWrapper
                                 profileStartTime:(uint64_t)profileStartTime
{
    if (self = [super init]) {
        _cpuTimeSeries = [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];
        _memoryFootprintTimeSeries = [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];
        _thermalStateChanges = [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];
        _powerLevelStateChanges = [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];
        _memoryPressureStateChanges =
            [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];

        _notificationCenter = notificationCenterWrapper;
        _profileStartTime = profileStartTime;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - Public

- (void)start
{
    [self registerSampler];
    [self registerStateChangeNotifications];
    [self registerMemoryPressureWarningHandler];
}

- (void)stop
{
    [_timer invalidate];
    dispatch_source_cancel(_memoryWarningSource);
    [_notificationCenter removeObserver:self
                                   name:NSProcessInfoThermalStateDidChangeNotification
                                 object:NSProcessInfo.processInfo];
    [_notificationCenter removeObserver:self
                                   name:NSProcessInfoPowerStateDidChangeNotification
                                 object:NSProcessInfo.processInfo];
}

- (NSData *)serialize
{
    // TODO: implement
    return [[NSData alloc] init];
}

#pragma mark - Private

- (void)registerSampler
{
    _timer = [NSTimer scheduledTimerWithTimeInterval:kSentryMetricProfilerInterval
                                             repeats:YES
                                               block:^(NSTimer *_Nonnull timer) {
                                                   [self recordCPUPercentage];
                                                   [self recordMemoryFootprint];
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
    const auto queueAttributes
        = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _memoryWarningQueue = dispatch_queue_create("io.sentry.queue.memory-warnings", queueAttributes);
    _memoryWarningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
        DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN
            | DISPATCH_MEMORYPRESSURE_CRITICAL,
        _memoryWarningQueue);
    dispatch_source_set_event_handler(_memoryWarningSource, ^{
        [self recordMemoryPressureState:dispatch_source_get_data(self->_memoryWarningSource)];
    });
    dispatch_resume(_memoryWarningSource);
}

- (void)registerStateChangeNotifications
{
    // According to Apple docs: "To receive NSProcessInfoThermalStateDidChangeNotification, you must
    // access the thermalState prior to registering for the notification." (from
    // https://developer.apple.com/documentation/foundation/nsprocessinfothermalstatedidchangenotification/)
    [self recordThermalState];

    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo."
    [_notificationCenter addObserver:self
                            selector:@selector(handleThermalStateChangeNotification:)
                                name:NSProcessInfoThermalStateDidChangeNotification
                              object:NSProcessInfo.processInfo];

    // According to Apple docs: "This notification is posted on the global dispatch queue. The
    // object associated with the notification is NSProcessInfo.processInfo."
    [_notificationCenter addObserver:self
                            selector:@selector(handleThermalStateChangeNotification:)
                                name:NSProcessInfoPowerStateDidChangeNotification
                              object:NSProcessInfo.processInfo];
}

- (void)handleThermalStateChangeNotification:(NSNotification *)note
{
    [self recordThermalState];
}

- (void)handlePowerLevelStateChangeNotification:(NSNotification *)note
{
    [self recordPowerLevelState];
}

- (void)recordThermalState
{
    [_thermalStateChanges
        addObject:[self metricEntryForValue:@(NSProcessInfo.processInfo.thermalState)]];
}

- (void)recordPowerLevelState
{
    [_powerLevelStateChanges
        addObject:[self metricEntryForValue:@(NSProcessInfo.processInfo.lowPowerModeEnabled)]];
}

- (void)recordMemoryPressureState:(uintptr_t)memoryPressureState
{
    [_memoryPressureStateChanges addObject:[self metricEntryForValue:@(memoryPressureState)]];
}

- (void)recordMemoryFootprint
{
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (SENTRY_PROF_LOG_KERN_RETURN(
            task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count))
        == KERN_SUCCESS) {
        mach_vm_size_t footprintBytes;
        if (count >= TASK_VM_INFO_REV1_COUNT) {
            footprintBytes = info.phys_footprint;
        } else {
            footprintBytes = info.resident_size;
        }

        [_memoryFootprintTimeSeries addObject:[self metricEntryForValue:@(footprintBytes)]];
    }
}

- (void)recordCPUPercentage
{
    // TODO: implement
}

- (NSDictionary<NSString *, NSNumber *> *)metricEntryForValue:(NSNumber *)value
{
    return @{
        @"value" : value,
        @"elapsed_since_start_ns" : @(getDurationNs(_profileStartTime, getAbsoluteTime()))
    };
}

@end
