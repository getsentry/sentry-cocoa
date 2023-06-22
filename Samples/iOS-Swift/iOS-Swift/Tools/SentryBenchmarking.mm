#import "SentryBenchmarking.h"
#include <chrono>
#include <mach/clock.h>
#include <mach/mach.h>
#include <pthread.h>
#include <string>
#import <thread>

#define SENTRY_BENCHMARKING_THREAD_NAME "io.sentry.benchmark.sampler-thread"

@implementation SentryBenchmarkResult

- (instancetype)initWithStart:(SentryBenchmarkReading *)start
                          end:(SentryBenchmarkReading *)end
       aggregatedSampleResult:(SentrySampledBenchmarkResults *)aggregatedSampleResult
{
    if (!(self = [super init])) {
        return nil;
    }

    _results = [[SentryBenchmarkReading alloc] init];

    _results.cpu = [[SentryCPUReading alloc] init];
    _results.cpu.systemTicks = end.cpu.systemTicks - start.cpu.systemTicks;
    _results.cpu.userTicks = end.cpu.systemTicks - start.cpu.userTicks;
    _results.cpu.idleTicks = end.cpu.idleTicks - start.cpu.idleTicks;

    _results.power = [[SentryPowerReading alloc] init];
    _results.power.info = /* task_power_info_v2 */ {
        /* task_power_info_data_t */ {
            end.power.info.cpu_energy.total_user - start.power.info.cpu_energy.total_user,
            end.power.info.cpu_energy.total_system - start.power.info.cpu_energy.total_system,
            end.power.info.cpu_energy.task_interrupt_wakeups
                - start.power.info.cpu_energy.task_interrupt_wakeups,
            end.power.info.cpu_energy.task_platform_idle_wakeups
                - start.power.info.cpu_energy.task_platform_idle_wakeups,
            end.power.info.cpu_energy.task_timer_wakeups_bin_1
                - start.power.info.cpu_energy.task_timer_wakeups_bin_1,
            end.power.info.cpu_energy.task_timer_wakeups_bin_2
                - start.power.info.cpu_energy.task_timer_wakeups_bin_2 },
        /* gpu_energy_data */
        { end.power.info.gpu_energy.task_gpu_utilisation
                - start.power.info.gpu_energy.task_gpu_utilisation,
            end.power.info.gpu_energy.task_gpu_stat_reserved0
                - start.power.info.gpu_energy.task_gpu_stat_reserved1,
            end.power.info.gpu_energy.task_gpu_stat_reserved1
                - start.power.info.gpu_energy.task_gpu_stat_reserved1,
            end.power.info.gpu_energy.task_gpu_stat_reserved2
                - start.power.info.gpu_energy.task_gpu_stat_reserved2 },
#if defined(__arm__) || defined(__arm64__)
        end.power.info.task_energy - start.power.info.task_energy,
#endif /* defined(__arm__) || defined(__arm64__) */
        end.power.info.task_ptime - start.power.info.task_ptime,
        end.power.info.task_pset_switches - start.power.info.task_pset_switches
    };

    _results.contextSwitches = end.contextSwitches - start.contextSwitches;

    _sampledResults = aggregatedSampleResult;

    return self;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"Endpoint results: %@; cumulative sampled results: %@",
                     _results.debugDescription, _sampledResults.debugDescription];
}

@end

@implementation SentryBenchmarkReading

+ (NSString *)debugDescription
{
}

@end

@implementation SentrySampledBenchmarkResults

- (NSString *)debugDescription
{
    const auto result = [NSMutableString string];
    [_aggregatedCPUUsagePerCore enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { [result appendFormat:@"Core %lu: %.1f%%; ", idx, obj.floatValue]; }];
    return [result stringByReplacingCharactersInRange:NSMakeRange(result.length - 2, 2)
                                           withString:@""];
}

@end

@implementation SentryPowerReading

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

/**
 * Only used to hold data as it is read; not used to hold results calculations. For results, see the
 * other properties.
 */
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

- (uint64_t)totalTicks
{
    return _systemTicks + _userTicks;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"CPU ticks: %llu", [self totalTicks]];
}

@end

@implementation SentryThreadBasicInfo
@end

@implementation SentryBenchmarkSample
@end

namespace {
const auto frequencyHz = 10;
const auto intervalNs = 1e9 / frequencyHz;

const auto samples = [NSMutableArray<SentryBenchmarkSample *> array];

dispatch_source_t source;
dispatch_queue_t queue;

SentryBenchmarkReading *startReading;

NSArray<NSNumber *> *
aggregatedCPUUsagePerCore()
{
    const auto totalUsages = [NSMutableArray<NSNumber *> array];
    for (SentryBenchmarkSample *sample in samples) {
        [sample.cpuUsagePerCore enumerateObjectsUsingBlock:^(
            NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if (totalUsages.count <= idx) {
                totalUsages[idx] = obj;
            } else {
                totalUsages[idx] = @(totalUsages[idx].doubleValue + obj.doubleValue);
            }
        }];
    }
    const auto averageUsages = [NSMutableArray<NSNumber *> array];
    for (NSNumber *totalUsage in totalUsages) {
        [averageUsages addObject:@(totalUsage.doubleValue / samples.count)];
    }
    return averageUsages;
}

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
NSArray<NSNumber *> *
cpuUsagePerCore(NSError **error)
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
                       userInfo:@ {
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

    return result;
}

/// @note: Implementation ported from @c SentryThreadHandle.hpp .
NSDictionary<NSString *, SentryThreadBasicInfo *> *
cpuInfoByThread(void)
{
    const auto dict = [NSMutableDictionary<NSString *, SentryThreadBasicInfo *> dictionary];
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
                const auto threadInfo = [[SentryThreadBasicInfo alloc] init];
                threadInfo.threadInfo = data;
                dict[[NSString stringWithUTF8String:namestr.c_str()]] = threadInfo;
            }
        }
    }
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
    return dict;
}

NSDictionary<NSString *, SentryThreadBasicInfo *> *_Nullable aggregateCPUUsagePerThread()
{
    if (samples.count < 2) {
        printf("[Sentry Benchmark] not enough samples were gathered to compute CPU usage.\n");
        return nil;
    }

    // definition of thread_basic_info from mach/thread_info.h:
    //    struct thread_basic_info {
    //        time_value_t    user_time;      /* user run time */
    //        time_value_t    system_time;    /* system run time */
    //        integer_t       cpu_usage;      /* scaled cpu usage percentage */
    //        policy_t        policy;         /* scheduling policy in effect */
    //        integer_t       run_state;      /* run state (see below) */
    //        integer_t       flags;          /* various flags (see below) */
    //        integer_t       suspend_count;  /* suspend count for thread */
    //        integer_t       sleep_time;     /* number of seconds that thread
    //                                         *  has been sleeping */
    //    };

    const auto userTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto systemTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto suspendCountTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto sleepTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto cpuUsages =
        [NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> dictionary];
    for (auto i = 0; i < samples.count - 2; i++) {
        const auto lastSample = samples[i];
        const auto thisSample = samples[i + 1];

        const auto afterKeys = [NSSet<NSString *> setWithArray:thisSample.threadInfos.allKeys];
        const auto persistedThreads =
            [NSMutableSet<NSString *> setWithArray:lastSample.threadInfos.allKeys];
        [persistedThreads intersectSet:afterKeys];
        const auto destroyedThreads =
            [NSMutableSet<NSString *> setWithArray:lastSample.threadInfos.allKeys];
        [destroyedThreads minusSet:persistedThreads];

        for (NSString *key : persistedThreads) {
            const auto lastThreadInfo = lastSample.threadInfos[key].threadInfo;
            const auto thisThreadInfo = thisSample.threadInfos[key].threadInfo;

            const auto lastSystemTime_ms = lastThreadInfo.system_time.seconds * 1e6
                + lastThreadInfo.system_time.microseconds;
            const auto thisSystemTime_ms = thisThreadInfo.system_time.seconds * 1e6
                + thisThreadInfo.system_time.microseconds;

            const auto lastUserTime_ms
                = lastThreadInfo.user_time.seconds * 1e6 + lastThreadInfo.user_time.microseconds;
            const auto thisUserTime_ms
                = thisThreadInfo.user_time.seconds * 1e6 + thisThreadInfo.user_time.microseconds;

            const auto lastSleepTime_s = lastThreadInfo.sleep_time;
            const auto thisSleepTime_s = thisThreadInfo.sleep_time;

            const auto lastSuspendCount = lastThreadInfo.suspend_count;
            const auto thisSuspendCount = thisThreadInfo.suspend_count;

            const auto lastCPUUsage = lastThreadInfo.cpu_usage;
            const auto thisCPUUsage = thisThreadInfo.cpu_usage;

            if (thisSystemTime_ms + thisUserTime_ms < lastSystemTime_ms + lastUserTime_ms) {
                // thread id was *likely* reassigned to a new thread since last sample
                [destroyedThreads addObject:key];
                continue;
            }

            const auto systemTimeDelta = thisSystemTime_ms - lastSystemTime_ms;
            const auto userTimeDelta = thisUserTime_ms - lastUserTime_ms;
            const auto sleepTimeDelta = thisSleepTime_s - lastSleepTime_s;
            const auto suspendCountDelta = thisSuspendCount - lastSuspendCount;

            if (!systemTimeTotals[key]) {
                systemTimeTotals[key] = @(systemTimeDelta);
                userTimeTotals[key] = @(userTimeDelta);
                sleepTimeTotals[key] = @(sleepTimeDelta);
                suspendCountTotals[key] = @(suspendCountDelta);
                cpuUsages[key] = [NSMutableArray<NSNumber *>
                    arrayWithObjects:@(lastCPUUsage), @(thisCPUUsage), nil];
            } else {
                systemTimeTotals[key] = @(systemTimeDelta + systemTimeTotals[key].integerValue);
                userTimeTotals[key] = @(userTimeDelta + userTimeTotals[key].integerValue);
                sleepTimeTotals[key] = @(sleepTimeDelta + sleepTimeTotals[key].integerValue);
                suspendCountTotals[key] =
                    @(suspendCountDelta + suspendCountTotals[key].integerValue);
                [cpuUsages[key] addObject:@(lastCPUUsage)];
                [cpuUsages[key] addObject:@(thisCPUUsage)];
            }
        }
    }
    const auto cpuUsageAverages = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    [cpuUsages enumerateKeysAndObjectsUsingBlock:^(
        NSString *_Nonnull key, NSMutableArray<NSNumber *> *_Nonnull obj, BOOL *_Nonnull stop) {
        auto total = 0;
        for (NSNumber *cpuUsage in obj) {
            total += cpuUsage.intValue;
        }
        cpuUsageAverages[key] = @((double)total / obj.count);
    }];

    const auto aggregatedThreadInfos =
        [NSMutableDictionary<NSString *, SentryThreadBasicInfo *> dictionary];
    for (NSString *key in userTimeTotals.allKeys) {
        thread_basic_info threadInfo;

        // !!!: we'll store the time totals only in microseconds; they are 32 bit int fields, so can
        // represent up to about 35 minutes each
        threadInfo.user_time = { 0, userTimeTotals[key].intValue };
        threadInfo.system_time = { 0, systemTimeTotals[key].intValue };

        threadInfo.sleep_time = sleepTimeTotals[key].intValue;
        threadInfo.cpu_usage = cpuUsageAverages[key].intValue;
        threadInfo.suspend_count = suspendCountTotals[key].intValue;

        const auto threadInfoWrapper = [[SentryThreadBasicInfo alloc] init];
        threadInfoWrapper.threadInfo = threadInfo;
        aggregatedThreadInfos[key] = threadInfoWrapper;
    }

    return aggregatedThreadInfos;
}
} // namespace

@implementation SentryBenchmarking

+ (SentryBenchmarkReading *)gatherBenchmarkReading
{
    const auto reading = [[SentryBenchmarkReading alloc] init];
    reading.cpu = [self cpuTicks:nil];
    reading.power = [self powerUsage:nil];
    reading.contextSwitches = [[self numContextSwitches:nil] longLongValue];
    return reading;
}

+ (void)recordSample
{
    const auto sample = [[SentryBenchmarkSample alloc] init];
    sample.threadInfos = cpuInfoByThread();
    sample.cpuUsagePerCore = cpuUsagePerCore(nil);
    [samples addObject:sample];
}

+ (void)start
{
    startReading = [self gatherBenchmarkReading];

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

    const NSMutableDictionary<NSString *, SentryThreadBasicInfo *> *aggregatedResults =
        [aggregateCPUUsagePerThread() mutableCopy];
    [samples removeAllObjects];
    if (!aggregatedResults) {
        return nil;
    }

    const uint64_t profilerSystemTime_ms
        = aggregatedResults[@"io.sentry.SamplingProfiler"].threadInfo.system_time.microseconds;
    const uint64_t profilerUserTime_ms
        = aggregatedResults[@"io.sentry.SamplingProfiler"].threadInfo.user_time.microseconds;
    [aggregatedResults removeObjectForKey:@"io.sentry.SamplingProfiler"];
    [aggregatedResults removeObjectForKey:@"io.sentry.SamplingProfiler"];

    __block auto appSystemTime_ms = 0ULL;
    __block auto appUserTime_ms = 0ULL;
    [aggregatedResults enumerateKeysAndObjectsUsingBlock:^(
        NSString *_Nonnull key, SentryThreadBasicInfo *_Nonnull obj, BOOL *_Nonnull stop) {
        appSystemTime_ms += obj.threadInfo.system_time.microseconds;
        appUserTime_ms += obj.threadInfo.user_time.microseconds;
    }];

    return [NSString stringWithFormat:@"%llu,%llu,%llu,%llu", profilerSystemTime_ms,
                     profilerUserTime_ms, appSystemTime_ms, appUserTime_ms];
}

+ (SentryBenchmarkResult *)stop
{
    dispatch_cancel(source);
    [self recordSample];

    const auto sampleResult = [[SentrySampledBenchmarkResults alloc] init];
    sampleResult.aggregatedThreadInfo = aggregateCPUUsagePerThread();
    sampleResult.aggregatedCPUUsagePerCore = aggregatedCPUUsagePerCore();
    sampleResult.allSamples = [samples copy];
    const auto result = [[SentryBenchmarkResult alloc] initWithStart:startReading
                                                                 end:[self gatherBenchmarkReading]
                                              aggregatedSampleResult:sampleResult];

    [samples removeAllObjects];

    return result;
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

    const auto reading = [[SentryPowerReading alloc] init];
    reading.info = powerInfo;
    return reading;
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
