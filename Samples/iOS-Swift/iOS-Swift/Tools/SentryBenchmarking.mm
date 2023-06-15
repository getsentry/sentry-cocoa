#import "SentryBenchmarking.h"
#include <chrono>
#include <mach/clock.h>
#include <mach/mach.h>
#include <pthread.h>
#include <string>
#import <thread>

#define SENTRY_BENCHMARKING_THREAD_NAME "io.sentry.benchmark.sampler-thread"

@implementation SentryBenchmarkResult

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"CPU ticks:\nsystem: %lld; user: %lld; idle: %lld\nPower "
                                      @"usage:\ncpu: %lld; gpu: %lld\ncontext switches: %lld",
                     _cpuTicksSystem, _cpuTicksUser, _cpuTicksIdle, _cpuPower, _gpuPower,
                     _contextSwitches];
}

- (SentryBenchmarkResult *)diff:(SentryBenchmarkResult *)other
{
    const auto diff = [[SentryBenchmarkResult alloc] init];
    diff.cpuTicksSystem = self.cpuTicksSystem - other.cpuTicksSystem;
    diff.cpuTicksUser = self.cpuTicksUser - other.cpuTicksUser;
    diff.cpuTicksIdle = self.cpuTicksIdle - other.cpuTicksIdle;
    diff.cpuPower = self.cpuPower - other.cpuPower;
    diff.gpuPower = self.gpuPower - other.gpuPower;
    diff.contextSwitches = self.contextSwitches - other.contextSwitches;
    return diff;
}

@end

@implementation SentryBenchmarkReading

- (instancetype)initWithCPUTickInfo:(SentryCPUReading *)cpuTickInfo
                         powerUsage:(SentryPowerReading *)powerUsage
                    contextSwitches:(uint64_t)contextSwitches
{
    if (!(self = [super init])) {
        return nil;
    }

    _cpuReading = cpuTickInfo;
    _powerReading = powerUsage;
    _contextSwitches = contextSwitches;

    return self;
}

- (SentryBenchmarkResult *)diff:(SentryBenchmarkReading *)other
{
    const auto diff = [[SentryBenchmarkResult alloc] init];
    diff.cpuTicksSystem
        = (int64_t)self.cpuReading.systemTicks - (int64_t)other.cpuReading.systemTicks;
    diff.cpuTicksUser = (int64_t)self.cpuReading.userTicks - (int64_t)other.cpuReading.userTicks;
    diff.cpuTicksIdle = (int64_t)self.cpuReading.idleTicks - (int64_t)other.cpuReading.idleTicks;

    diff.cpuPower = (int64_t)self.powerReading.totalCPU - (int64_t)other.powerReading.totalCPU;
    diff.gpuPower = (int64_t)self.powerReading.totalGPU - (int64_t)other.powerReading.totalGPU;

    diff.contextSwitches = (int64_t)self.contextSwitches - (int64_t)other.contextSwitches;

    return diff;
}

@end

@implementation SentryCPUCoreReadings

- (instancetype)initWithUsagePercentages:(NSArray<NSNumber *> *)usagePercentages
{
    if (!(self = [super init])) {
        return nil;
    }

    _usagePercentages = usagePercentages;
    return self;
}

- (NSString *)debugDescription
{
    const auto result = [NSMutableString string];
    [_usagePercentages enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { [result appendFormat:@"Core %lu: %.1f%%; ", idx, obj.floatValue]; }];
    return [result stringByReplacingCharactersInRange:NSMakeRange(result.length - 2, 2)
                                           withString:@""];
}

@end

@implementation SentryPowerReading

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

- (NSString *)debugDescription
{
    return [NSString
        stringWithFormat:@"totalCPU: %llu; totalGPU: %llu", [self totalCPU], [self totalGPU]];
}

@end

@interface
SentryCPUReading ()
@property host_cpu_load_info_data_t data;
@end

@implementation SentryCPUReading

- (instancetype)initWithData:(host_cpu_load_info_data_t)data
{
    self = [super init];
    if (self) {
        _data = data;
        _systemTicks = data.cpu_ticks[CPU_STATE_SYSTEM];
        _userTicks = data.cpu_ticks[CPU_STATE_USER] + data.cpu_ticks[CPU_STATE_NICE];
        _idleTicks = data.cpu_ticks[CPU_STATE_IDLE];
    }
    return self;
}

- (uint64_t)total
{
    return _systemTicks + _userTicks;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"CPU ticks: %llu", [self total]];
}

@end

@interface SentryBenchmarkSample : NSObject

@property NSDictionary<NSString *, NSArray<NSNumber *> *> *cpuUsagePerThread;
@property SentryCPUCoreReadings *cpuUsagePerCore;

@end

@implementation SentryBenchmarkSample
@end

namespace {
/// @note: Implementation ported from @c SentryThreadHandle.hpp .
NSDictionary<NSString *, NSArray<NSNumber *> *> *
cpuInfoByThread(void)
{
    const auto dict = [NSMutableDictionary<NSString *, NSArray<NSNumber *> *> dictionary];
    mach_msg_type_number_t count;
    thread_act_array_t list;

    if (task_threads(mach_task_self(), &list, &count) == KERN_SUCCESS) {
        for (decltype(count) i = 0; i < count; i++) {
            const auto thread = list[i];

            // get thread name to check for the sampling profiler thread
            const auto handle = pthread_from_mach_thread_np(thread);
            std::string namestr;
            if (handle == nullptr) {
                continue;
            }
            char name[128];
            if (pthread_getname_np(handle, name, sizeof(name)) != 0) {
                continue;
            }
            namestr = std::string(name);
            if (namestr.length() == 0) {
                namestr = std::to_string(thread);
            }

            if (namestr == SENTRY_BENCHMARKING_THREAD_NAME) {
                continue;
            }

            mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
            thread_basic_info_data_t data;
            // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
            if (thread_info(
                    thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &count)
                == KERN_SUCCESS) {
                const auto system_time_micros
                    = data.system_time.seconds * 1e6 + data.system_time.microseconds;
                const auto user_time_micros
                    = data.user_time.seconds * 1e6 + data.user_time.microseconds;
                dict[[NSString stringWithUTF8String:namestr.c_str()]] =
                    @[ @(system_time_micros), @(user_time_micros), @(data.cpu_usage) ];
            }
        }
    }
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
    return dict;
}

const auto frequencyHz = 10;
const auto intervalNs = 1e9 / frequencyHz;

const auto samples = [NSMutableArray<SentryBenchmarkSample *> array];

dispatch_source_t source;
dispatch_queue_t queue;

SentryBenchmarkReading *startStats;
}

@implementation SentryBenchmarking

+ (SentryBenchmarkReading *)gatherBenchmarkStats
{
    return [[SentryBenchmarkReading alloc]
        initWithCPUTickInfo:[self cpuTicks:nil]
                 powerUsage:[self powerUsage:nil]
            contextSwitches:[[self numContextSwitches:nil] longLongValue]];
}

+ (void)recordSample
{
    const auto sample = [[SentryBenchmarkSample alloc] init];
    sample.cpuUsagePerThread = cpuInfoByThread();
    sample.cpuUsagePerCore = [self cpuUsagePerCore:nil];
    [samples addObject:sample];
}

+ (void)start
{
    startStats = [self gatherBenchmarkStats];

    const auto attr = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    const auto leewayNs = intervalNs / 2;
    queue = dispatch_queue_create("io.sentry.benchmark.gcd-scheduler", attr);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_event_handler(source, ^{ [self recordSample]; });
    dispatch_source_set_timer(
        source, dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, leewayNs);
    dispatch_resume(source);
}

+ (NSString *)stopAndReturnProfilerThreadUsage
{
    dispatch_cancel(source);

    [self recordSample];

    if (samples.count < 2) {
        printf("[Sentry Benchmark] not enough samples were gathered to compute CPU usage.\n");
        return nil;
    }

    const auto systemTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto userTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    for (auto i = 0; i < samples.count - 2; i++) {
        const auto before = samples[i];
        const auto after = samples[i + 1];

        const auto afterKeys = [NSSet<NSString *> setWithArray:after.cpuUsagePerThread.allKeys];
        const auto persistedThreads =
            [NSMutableSet<NSString *> setWithArray:before.cpuUsagePerThread.allKeys];
        [persistedThreads intersectSet:afterKeys];
        const auto destroyedThreads =
            [NSMutableSet<NSString *> setWithArray:before.cpuUsagePerThread.allKeys];
        [destroyedThreads minusSet:persistedThreads];

        for (NSString *key : persistedThreads) {
            const auto lastSystemTime = before.cpuUsagePerThread[key][0].integerValue;
            const auto thisSystemTime = after.cpuUsagePerThread[key][0].integerValue;
            const auto lastUserTime = before.cpuUsagePerThread[key][1].integerValue;
            const auto thisUserTime = after.cpuUsagePerThread[key][1].integerValue;
            if (thisSystemTime + thisUserTime < lastSystemTime + lastUserTime) {
                // thread id was reassigned to a new thread since last sample
                [destroyedThreads addObject:key];
                continue;
            }
            const auto systemTimeDelta = thisSystemTime - lastSystemTime;
            const auto userTimeDelta = thisUserTime - lastUserTime;
            if (!systemTimeTotals[key]) {
                systemTimeTotals[key] = @(systemTimeDelta);
                userTimeTotals[key] = @(userTimeDelta);
            } else {
                systemTimeTotals[key] = @(systemTimeDelta + systemTimeTotals[key].integerValue);
                userTimeTotals[key] = @(userTimeDelta + userTimeTotals[key].integerValue);
            }
        }
    }

    [samples removeAllObjects];

    const auto profilerSystemTime = systemTimeTotals[@"io.sentry.SamplingProfiler"].integerValue;
    const auto profilerUserTime = userTimeTotals[@"io.sentry.SamplingProfiler"].integerValue;
    [systemTimeTotals removeObjectForKey:@"io.sentry.SamplingProfiler"];
    [userTimeTotals removeObjectForKey:@"io.sentry.SamplingProfiler"];
    const auto appSystemTime
        = ((NSNumber *)[systemTimeTotals.allValues valueForKeyPath:@"@sum.self"]).integerValue;
    const auto appUserTime
        = ((NSNumber *)[userTimeTotals.allValues valueForKeyPath:@"@sum.self"]).integerValue;

    return [NSString stringWithFormat:@"%ld,%ld,%ld,%ld", profilerSystemTime, profilerUserTime,
                     appSystemTime, appUserTime];
}

+ (SentryBenchmarkResult *)stop
{
    const auto endStats = [self gatherBenchmarkStats];
}

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
+ (nullable SentryPowerReading *)powerUsage:(NSError **)error
{
    struct task_power_info_v2 powerInfo;

    mach_msg_type_number_t size = TASK_POWER_INFO_V2_COUNT;

    task_t task = mach_task_self();
    kern_return_t kr = task_info(task, TASK_POWER_INFO_V2, (task_info_t)&powerInfo, &size);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = [NSError
                errorWithDomain:@"io.sentry.error.benchmarking"
                           code:1
                       userInfo:@{
                           NSLocalizedFailureReasonErrorKey : [NSString
                               stringWithFormat:@"Error with task_info(…TASK_POWER_INFO_V2…): %d.",
                               kr]
                       }];
        }
        return nil;
    }

    return [[SentryPowerReading alloc] initWithInfo:powerInfo];
}

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
+ (SentryCPUCoreReadings *)cpuUsagePerCore:(NSError **)error
{
    natural_t numCPUs = 0U;
    processor_info_array_t cpuInfo;
    mach_msg_type_number_t numCPUInfo;
    const auto status = host_processor_info(
        mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = [NSError
                errorWithDomain:@"io.sentry.error.benchmarking"
                           code:2
                       userInfo:@{
                           NSLocalizedFailureReasonErrorKey : [NSString
                               stringWithFormat:@"host_processor_info reported an error: %d",
                               status]
                       }];
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

    return [[SentryCPUCoreReadings alloc] initWithUsagePercentages:result];
}

+ (nullable NSNumber *)numContextSwitches:(NSError **)error
{
    task_events_info info;
    mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
    const auto status = task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error =
                [NSError errorWithDomain:@"io.sentry.error.benchmarking"
                                    code:3
                                userInfo:@{
                                    NSLocalizedFailureReasonErrorKey : [NSString
                                        stringWithFormat:@"task_info reported an error: %d", status]
                                }];
        }
        return nil;
    }
    return @(info.csw);
}

+ (nullable SentryCPUReading *)cpuTicks:(NSError **)error
{
    kern_return_t kr;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    host_cpu_load_info_data_t data;

    kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (int *)&data, &count);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = [NSError
                errorWithDomain:@"io.sentry.error.benchmarking"
                           code:4
                       userInfo:@{
                           NSLocalizedFailureReasonErrorKey :
                               [NSString stringWithFormat:@"task_info reported an error: %d", kr]
                       }];
        }
        return nil;
    }

    return [[SentryCPUReading alloc] initWithData:data];
}

@end
