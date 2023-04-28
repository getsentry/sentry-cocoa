#import "SentrySystemWrapper.h"
#import "SentryError.h"
#import <mach/mach.h>
#include <pthread.h>
#import <sys/sysctl.h>

@implementation SentryCPUUsagePerCore

- (instancetype)initWithUsages:(NSArray<NSNumber *> *)usages
{
    if (!(self = [super init])) {
        return nil;
    }

    _usages = usages;
    return self;
}

- (NSString *)debugDescription
{
    const auto result = [NSMutableString string];
    [_usages enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { [result appendFormat:@"Core %lu: %.1f%%; ", idx, obj.floatValue]; }];
    return [result stringByReplacingCharactersInRange:NSMakeRange(result.length - 2, 2)
                                           withString:@""];
}

@end

@implementation SentryPowerUsageStats

- (instancetype)initWithInfo:(task_power_info_v2)info
{
    if (!(self = [super init])) {
        return nil;
    }
    _info = info;
    return self;
}

- (uint64_t)totalCPU
{
    return _info.cpu_energy.total_system + _info.cpu_energy.total_user;
}

- (uint64_t)totalGPU
{
    return _info.gpu_energy.task_gpu_utilisation;
}

@end

@implementation SentryThreadCPUUsage

- (instancetype)initWithData:(thread_basic_info_data_t)data
{
    if (!(self = [super init])) {
        return nil;
    }
    _data = data;
    return self;
}

- (uint64_t)total
{
    return _data.system_time.seconds * 1000000 + _data.system_time.microseconds
        + _data.user_time.seconds * 1000000 + _data.user_time.microseconds;
}

@end

@implementation SentryCPUUsagePerThread

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }
    _usages = [NSMutableDictionary<NSNumber *, SentryThreadCPUUsage *> dictionary];
    return self;
}

@end

@implementation SentryCPUTickInfo

- (instancetype)initWithData:(host_cpu_load_info_data_t)data
{
    self = [super init];
    if (self) {
        _system = data.cpu_ticks[CPU_STATE_SYSTEM];
        _user = data.cpu_ticks[CPU_STATE_USER] + data.cpu_ticks[CPU_STATE_NICE];
        _idle = data.cpu_ticks[CPU_STATE_IDLE];
    }
    return self;
}

- (uint64_t)total
{
    return _system + _user;
}

@end

@implementation SentryCPUInfo

- (NSString *)debugDescription
{
    const auto result = [NSMutableString string];
    for (uint64_t perfLevel = 0; perfLevel < _performanceLevels; perfLevel++) {
        [result appendFormat:@"perf level %llu cores: physical max: %@; enabled: %@; logical max: "
                             @"%@; enabled: %@\n",
                perfLevel, _availablePhysicalCoresPerPerformanceLevel[perfLevel],
                _enabledPhysicalCoresPerPerformanceLevel[perfLevel],
                _availableLogicalCoresPerPerformanceLevel[perfLevel],
                _enabledLogicalCoresPerPerformanceLevel[perfLevel]];
    }
    return [result stringByReplacingCharactersInRange:NSMakeRange(result.length - 1, 1)
                                           withString:@""];
}

@end

@implementation SentrySystemWrapper

/*
 * from https://developer.apple.com/forums/thread/91160
 *  powerInfo.task_energy is the total energy used by all threads
 *  - returned by calling task_info with TASK_POWER_INFO_V2
 *  - which calls task_power_info_locked
 *  - calculated by task_energy() (defined in darwin-xnu/osfmk/kern/task.c)
 *  - using ml_energy_stat (defined in darwin-xnu/osfmk/arm64/machine_routines.c)
 *  - which returns (thread_t)t->machine.energy_estimate_nj
 *
 * darwin-xnu/tests/task_info.c uses TASK_POWER_INFO_V2_COUNT for the size parameter
 *
 * TODO: can this be done per thread like the implementation of task_energy does? how to import the
 * kernel calls?
 */
- (nullable SentryPowerUsageStats *)powerUsage:(NSError **)error
{
    struct task_power_info_v2 powerInfo;

    mach_msg_type_number_t size = TASK_POWER_INFO_V2_COUNT;

    task_t task = mach_task_self();
    kern_return_t kr = task_info(task, TASK_POWER_INFO_V2, (task_info_t)&powerInfo, &size);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"Error with task_info(…TASK_POWER_INFO_V2…).", kr);
        }
        return nil;
    }

    return [[SentryPowerUsageStats alloc] initWithInfo:powerInfo];
}

- (SentryRAMBytes)memoryFootprintBytes:(NSError *__autoreleasing _Nullable *)error
{
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;

    const auto status = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", status);
        }
        return 0;
    }

    SentryRAMBytes footprintBytes;
    if (count >= TASK_VM_INFO_REV1_COUNT) {
        footprintBytes = info.phys_footprint;
    } else {
        footprintBytes = info.resident_size;
    }

    return footprintBytes;
}

- (SentryCPUUsagePerCore *)cpuUsagePerCore:(NSError **)error
{
    natural_t numCPUs = 0U;
    processor_info_array_t cpuInfo;
    mach_msg_type_number_t numCPUInfo;
    const auto status = host_processor_info(
        mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"host_processor_info reported an error.", status);
        }
        return nil;
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:numCPUs];
    for (natural_t core = 0U; core < numCPUs; ++core) {
        const auto indexBase = CPU_STATE_MAX * core;
        const float user = cpuInfo[indexBase + CPU_STATE_USER];
        const float sys = cpuInfo[indexBase + CPU_STATE_SYSTEM];
        const float nice = cpuInfo[indexBase + CPU_STATE_NICE];
        const float idle = cpuInfo[indexBase + CPU_STATE_IDLE];
        const auto inUse = user + sys + nice;
        const auto total = inUse + idle;
        const auto usagePercent = inUse / total * 100.f;
        [result addObject:@(usagePercent)];
    }

    return [[SentryCPUUsagePerCore alloc] initWithUsages:result];
    ;
}

- (nullable NSNumber *)numContextSwitches:(NSError **)error
{
    task_events_info info;
    mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
    const auto status = task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", status);
        }
        return 0;
    }
    return @(info.csw);
}

- (nullable SentryCPUUsagePerThread *)cpuUsagePerThread:(NSError **)error
{
    mach_msg_type_number_t count;
    thread_act_array_t list;

    const auto threadStatus = task_threads(mach_task_self(), &list, &count);
    if (threadStatus != KERN_SUCCESS) {
        return nil;
    }

    const auto result = [[SentryCPUUsagePerThread alloc] init];
    for (decltype(count) i = 0; i < count; i++) {
        const auto thread = list[i];

        const auto handle = pthread_from_mach_thread_np(thread);
        if (handle == nullptr) {
            continue;
        }

        char name[128];
        if (pthread_getname_np(handle, name, sizeof(name)) != 0) {
            continue;
        }

        mach_msg_type_number_t infoCount = THREAD_BASIC_INFO_COUNT;
        thread_basic_info_data_t data;

        // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
        const auto infoStatus = thread_info(
            thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &infoCount);
        if (infoStatus != KERN_SUCCESS) {
            continue;
        }

        result.usages[@(thread)] = [[SentryThreadCPUUsage alloc] initWithData:data];
    }

    return result;
}

- (nullable SentryCPUTickInfo *)cpuTicks:(NSError **)error
{
    kern_return_t kr;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    host_cpu_load_info_data_t data;

    kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (int *)&data, &count);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", kr);
        }
        return nil;
    }

    return [[SentryCPUTickInfo alloc] initWithData:data];
}

- (nullable NSNumber *)sysctlbynameWithName:(const char *)name error:(NSError **)error
{
    int result;
    size_t resultSize = sizeof(result);
    const auto status = sysctlbyname(name, &result, &resultSize, NULL, 0);
    if (status != KERN_SUCCESS) {
        NSLog(@"error: %s; %d", strerror(errno), status);
        return nil;
    }

    return @(result);
}

- (nullable SentryCPUInfo *)cpuInfo:(NSError **)error
{
#define SENTRY_SYSCTLBYNAME_ULL(name)                                                              \
    [self sysctlbynameWithName:"hw." name error:nil].unsignedLongLongValue
    const auto info = [[SentryCPUInfo alloc] init];
    info.availableLogicalCores = SENTRY_SYSCTLBYNAME_ULL("logicalcpu");
    info.enabledLogicalCores = SENTRY_SYSCTLBYNAME_ULL("logicalcpu_max");
    info.availablePhysicalCores = SENTRY_SYSCTLBYNAME_ULL("physicalcpu_max");
    info.enabledPhysicalCores = SENTRY_SYSCTLBYNAME_ULL("physicalcpu");

    info.performanceLevels = SENTRY_SYSCTLBYNAME_ULL("nperflevels");

    const auto availableLogicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto enabledLogicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto availablePhysicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
    const auto enabledPhysicalCoresPerPerformanceLevel = [NSMutableArray<NSNumber *> array];
#undef SENTRY_SYSCTLBYNAME_ULL

#define SENTRY_SYSCTLBYNAME_PERF(name, level)                                                      \
    [self sysctlbynameWithName:[NSString stringWithFormat:@"hw.perflevel%llu.%s", level, name]     \
                                   .UTF8String                                                     \
                         error:nil]
    for (uint64_t perfLevel = 0; perfLevel < info.performanceLevels; perfLevel++) {
        [availableLogicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("logicalcpu_max", perfLevel)];
        [enabledLogicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("logicalcpu", perfLevel)];
        [availablePhysicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("physicalcpu", perfLevel)];
        [enabledPhysicalCoresPerPerformanceLevel
            addObject:SENTRY_SYSCTLBYNAME_PERF("physicalcpu_max", perfLevel)];
    }
#undef SENTRY_SYSCTLBYNAME_PERF

    info.availableLogicalCoresPerPerformanceLevel = availableLogicalCoresPerPerformanceLevel;
    info.enabledLogicalCoresPerPerformanceLevel = enabledLogicalCoresPerPerformanceLevel;
    info.availablePhysicalCoresPerPerformanceLevel = availablePhysicalCoresPerPerformanceLevel;
    info.enabledPhysicalCoresPerPerformanceLevel = enabledPhysicalCoresPerPerformanceLevel;

    return info;
}

@end
