#import "SentryBenchmarking.h"
#include <chrono>
#include <mach/clock.h>
#include <mach/mach.h>
#import <mach/mach_time.h>
#include <pthread.h>
#include <string>
#import <thread>

#define SENTRY_BENCHMARKING_THREAD_NAME "io.sentry.benchmark.sampler-thread"

namespace {
const auto frequencyHz = 10;
// const auto frequencyHz = 0.01667; // use low frequency for long-lasting battery drain test
const auto intervalNs = 1e9 / frequencyHz;
const auto instantaneousReadingStaggerMs = 75;

uint64_t
machTime(void)
{
    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
        return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    } else {
        return mach_absolute_time();
    }
}

uint64_t
microsecondsFromTimeValue(time_value_t value)
{
    return value.seconds * 1e6 + value.microseconds;
}

NSArray<NSNumber *> *
aggregatedCPUUsagePerCore(NSArray<SentryBenchmarkSample *> *samples)
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

processor_info_array_t _Nullable processorInfo(natural_t *numCPUs, NSError **error)
{
    processor_info_array_t cpuInfo;
    mach_msg_type_number_t numCPUInfo = PROCESSOR_CPU_LOAD_INFO_COUNT;
    auto status = host_processor_info(
        mach_host_self(), PROCESSOR_CPU_LOAD_INFO, numCPUs, &cpuInfo, &numCPUInfo);
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
        return NULL;
    }
    return cpuInfo;
}

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
NSArray<NSNumber *> *
cpuUsagePerCore(NSError **error)
{
    natural_t numCPUsA = 0U;
    const auto first = processorInfo(&numCPUsA, error);
    if (first == NULL) {
        return nil;
    }

    // htop sleeps for 75 milliseconds between two samples:
    // https://github.com/htop-dev/htop/blob/37d30a3a7d6c96da018c960d6b6bfe11cc718aa8/CommandLine.c#L402-L405
    std::this_thread::sleep_for(std::chrono::milliseconds(instantaneousReadingStaggerMs));

    natural_t numCPUsB = 0U;
    const auto second = processorInfo(&numCPUsB, error);
    if (second == NULL) {
        return nil;
    }

    NSCAssert(numCPUsA == numCPUsB, @"Different number of cpus reported between calls");

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:numCPUsA];

    auto totalTicks = 0.0;
    for (natural_t state = 0U; state < CPU_STATE_MAX; ++state) {
        totalTicks += second[state] - first[state];
    }

    for (natural_t core = 0U; core < numCPUsA; ++core) {
        const auto indexBase = CPU_STATE_MAX * core;
        const float user = (second[indexBase + CPU_STATE_USER] - first[indexBase + CPU_STATE_USER])
            * 100.0 / totalTicks;
        const float sys
            = (second[indexBase + CPU_STATE_SYSTEM] - first[indexBase + CPU_STATE_SYSTEM]) * 100.0
            / totalTicks;
        const float nice = (second[indexBase + CPU_STATE_NICE] - first[indexBase + CPU_STATE_NICE])
            * 100.0 / totalTicks;
        [result addObject:@(user + sys + nice)];
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

            dict[[NSString stringWithUTF8String:namestr.c_str()]] =
                [[SentryThreadBasicInfo alloc] initForThread:thread error:nil];
        }
    }
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
    return dict;
}

NSDictionary<NSString *, SentryThreadBasicInfo *> *_Nullable aggregateCPUUsagePerThread(
    NSArray<SentryBenchmarkSample *> *samples)
{
    if (samples.count < 2) {
        printf("[Sentry Benchmark] not enough samples were gathered to compute CPU usage.\n");
        return nil;
    }

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

            const auto lastSystemTime_ms = microsecondsFromTimeValue(lastThreadInfo.system_time);
            const auto thisSystemTime_ms = microsecondsFromTimeValue(thisThreadInfo.system_time);

            const auto lastUserTime_ms = microsecondsFromTimeValue(lastThreadInfo.user_time);
            const auto thisUserTime_ms = microsecondsFromTimeValue(thisThreadInfo.user_time);

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

@implementation SentryBenchmarkResult

- (instancetype)initWithStart:(SentryBenchmarkReading *)start
                          end:(SentryBenchmarkReading *)end
       aggregatedSampleResult:(SentrySampledBenchmarkResults *)aggregatedSampleResult
{
    if (!(self = [super init])) {
        return nil;
    }

    _results = [[SentryBenchmarkReading alloc] init];

    _results.machTime = end.machTime - start.machTime;

    _results.cpu = [[SentryCPUReading alloc] init];
    _results.cpu.systemTicks = end.cpu.systemTicks - start.cpu.systemTicks;
    _results.cpu.userTicks = end.cpu.systemTicks - start.cpu.userTicks;
    _results.cpu.idleTicks = end.cpu.idleTicks - start.cpu.idleTicks;

    _results.power = [[SentryPowerReading alloc] init];
    _results.power.instantaneousInfo = /* task_power_info_v2 */ {
        /* task_power_info_data_t */ { end.power.instantaneousInfo.cpu_energy.total_user
                - start.power.instantaneousInfo.cpu_energy.total_user,
            end.power.instantaneousInfo.cpu_energy.total_system
                - start.power.instantaneousInfo.cpu_energy.total_system,
            end.power.instantaneousInfo.cpu_energy.task_interrupt_wakeups
                - start.power.instantaneousInfo.cpu_energy.task_interrupt_wakeups,
            end.power.instantaneousInfo.cpu_energy.task_platform_idle_wakeups
                - start.power.instantaneousInfo.cpu_energy.task_platform_idle_wakeups,
            end.power.instantaneousInfo.cpu_energy.task_timer_wakeups_bin_1
                - start.power.instantaneousInfo.cpu_energy.task_timer_wakeups_bin_1,
            end.power.instantaneousInfo.cpu_energy.task_timer_wakeups_bin_2
                - start.power.instantaneousInfo.cpu_energy.task_timer_wakeups_bin_2 },
        /* gpu_energy_data */
        { end.power.instantaneousInfo.gpu_energy.task_gpu_utilisation
                - start.power.instantaneousInfo.gpu_energy.task_gpu_utilisation,
            end.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved0
                - start.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved1,
            end.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved1
                - start.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved1,
            end.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved2
                - start.power.instantaneousInfo.gpu_energy.task_gpu_stat_reserved2 },
#if defined(__arm__) || defined(__arm64__)
        end.power.instantaneousInfo.task_energy - start.power.instantaneousInfo.task_energy,
#endif /* defined(__arm__) || defined(__arm64__) */
        end.power.instantaneousInfo.task_ptime - start.power.instantaneousInfo.task_ptime,
        end.power.instantaneousInfo.task_pset_switches
            - start.power.instantaneousInfo.task_pset_switches
    };

    _results.taskEvents = [[SentryTaskEventsReading alloc] init];
    _results.taskEvents.data = { end.taskEvents.data.faults - start.taskEvents.data.faults,
        end.taskEvents.data.pageins - start.taskEvents.data.pageins,
        end.taskEvents.data.cow_faults - start.taskEvents.data.cow_faults,
        end.taskEvents.data.messages_sent - start.taskEvents.data.messages_sent,
        end.taskEvents.data.messages_received - start.taskEvents.data.messages_received,
        end.taskEvents.data.syscalls_mach - start.taskEvents.data.syscalls_mach,
        end.taskEvents.data.syscalls_unix - start.taskEvents.data.syscalls_unix,
        end.taskEvents.data.csw - start.taskEvents.data.csw };

    _sampledResults = aggregatedSampleResult;

    return self;
}

- (NSString *)description
{
    return [NSString
        stringWithFormat:@"Start/end esults:\nmach time: %llu\n%@\ncumulative sampled results:\n%@",
        _results.machTime, _results.description, _sampledResults.description];
}

@end

@implementation SentryBenchmarkReading

- (instancetype)initWithError:(NSError *__autoreleasing _Nullable *)error
{
    if (!(self = [super init])) {
        _machTime = machTime();
        _cpu = [[SentryCPUReading alloc] initWithError:error];
        _power = [[SentryPowerReading alloc] initWithError:error];
        _taskEvents = [[SentryTaskEventsReading alloc] initWithError:error];
    }
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"cpu:\n%@\npower:\n%@\ntask events:\n%@",
                     self.cpu.description, self.power.description, self.taskEvents.description];
}

@end

@implementation SentrySampledBenchmarkResults

- (NSString *)description
{
    const auto results = [NSMutableArray array];

    const auto cores = [NSMutableArray array];
    [_aggregatedCPUUsagePerCore
        enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            [cores addObject:[NSString stringWithFormat:@"Core %lu: %.1f%%", idx, obj.floatValue]];
        }];
    [results addObject:[NSString stringWithFormat:@"Average core usages:\n%@",
                                 [cores componentsJoinedByString:@"; "]]];

    const auto threads = [NSMutableArray array];
    [_aggregatedThreadInfo enumerateKeysAndObjectsUsingBlock:^(
        NSString *_Nonnull key, SentryThreadBasicInfo *_Nonnull obj, BOOL *_Nonnull stop) {
        [threads addObject:[NSString stringWithFormat:@"Thread %@: %@", key, obj.description]];
    }];
    [results addObject:[NSString stringWithFormat:@"Cumulative thread usages:\n%@",
                                 [threads componentsJoinedByString:@"\n"]]];

    const auto samples = [NSMutableArray array];
    [_allSamples enumerateObjectsUsingBlock:^(
        SentryBenchmarkSample *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [samples addObject:[NSString stringWithFormat:@"===Sample===\n%@", obj.description]];
    }];
    [results addObject:[NSString stringWithFormat:@"Samples:\n%@",
                                 [samples componentsJoinedByString:@"\n"]]];

    return [results componentsJoinedByString:@"\n"];
}

@end

@implementation SentryPowerReading

- (instancetype)initWithError:(NSError *__autoreleasing _Nullable *)error
{
    if ((self = [super init])) {
        const auto first = [self powerInfoWithError:nil];

        // same 75 ms sleep like htop as we do for cpu usage per core
        std::this_thread::sleep_for(std::chrono::milliseconds(instantaneousReadingStaggerMs));
        _cumulativeInfo = [self powerInfoWithError:nil];

        _instantaneousInfo = {
            { _cumulativeInfo.cpu_energy.total_user - first.cpu_energy.total_user,
                _cumulativeInfo.cpu_energy.total_system - first.cpu_energy.total_system,
                _cumulativeInfo.cpu_energy.task_interrupt_wakeups
                    - first.cpu_energy.task_interrupt_wakeups,
                _cumulativeInfo.cpu_energy.task_platform_idle_wakeups
                    - first.cpu_energy.task_platform_idle_wakeups,
                _cumulativeInfo.cpu_energy.task_timer_wakeups_bin_1
                    - first.cpu_energy.task_timer_wakeups_bin_1,
                _cumulativeInfo.cpu_energy.task_timer_wakeups_bin_2
                    - first.cpu_energy.task_timer_wakeups_bin_2 },
            { _cumulativeInfo.gpu_energy.task_gpu_utilisation
                    - first.gpu_energy.task_gpu_utilisation,
                _cumulativeInfo.gpu_energy.task_gpu_stat_reserved0
                    - first.gpu_energy.task_gpu_stat_reserved0,
                _cumulativeInfo.gpu_energy.task_gpu_stat_reserved1
                    - first.gpu_energy.task_gpu_stat_reserved1,
                _cumulativeInfo.gpu_energy.task_gpu_stat_reserved2
                    - first.gpu_energy.task_gpu_stat_reserved2 },
#if defined(__arm__) || defined(__arm64__)
            _cumulativeInfo.task_energy - first.task_energy,
#endif /* defined(__arm__) || defined(__arm64__) */
            _cumulativeInfo.task_ptime - first.task_ptime,
            _cumulativeInfo.task_pset_switches - first.task_pset_switches,
        };

        UIDevice *_Nonnull device = UIDevice.currentDevice;
        _batteryLevel = device.batteryLevel;
        _batteryState = device.batteryState;

        NSProcessInfo *_Nonnull processInfo = NSProcessInfo.processInfo;
        _thermalState = processInfo.thermalState;
        _lowPowerModeEnabled = processInfo.lowPowerModeEnabled;
    }
    return self;
}

- (struct task_power_info_v2)powerInfoWithError:(NSError **)error
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
    }
    return powerInfo;
}

- (uint64_t)totalInstantaneousCPU
{
    return _instantaneousInfo.cpu_energy.total_system + _instantaneousInfo.cpu_energy.total_user;
}

- (uint64_t)totalCumulativeCPU
{
    return _cumulativeInfo.cpu_energy.total_system + _cumulativeInfo.cpu_energy.total_user;
}

- (NSString *)_thermalStateName
{
    switch (_thermalState) {
    case NSProcessInfoThermalStateNominal:
        return @"nominal";
    case NSProcessInfoThermalStateFair:
        return @"fair";
    case NSProcessInfoThermalStateSerious:
        return @"serious";
    case NSProcessInfoThermalStateCritical:
        return @"critical";
    default:
        NSAssert(NO, @"unknown thermal state: %lld", (long long)_thermalState);
        return nil;
    }
}

- (NSString *)nameForBatteryState:(UIDeviceBatteryState)state
{
    switch (state) {
    case UIDeviceBatteryStateCharging:
        return @"charging";
    case UIDeviceBatteryStateFull:
        return @"full";
    case UIDeviceBatteryStateUnknown:
        return @"unknown";
    case UIDeviceBatteryStateUnplugged:
        return @"unplugged";
    default:
        NSAssert(NO, @"unexpected battery state value: %ld", (long)state);
        return nil;
    }
}

- (NSString *)description
{
    const auto string = [NSMutableString
        stringWithFormat:
            @"battery state: %@; battery level: %.3f; low power mode? %@; thermalState: "
            @"%@; totalCPU: %llu; totalGPU: %llu",
        [self nameForBatteryState:_batteryState], _batteryLevel, _lowPowerModeEnabled ? @YES : @NO,
        [self _thermalStateName], [self totalInstantaneousCPU],
        _instantaneousInfo.gpu_energy.task_gpu_utilisation];
#if defined(__arm__) || defined(__arm64__)
    [string appendFormat:@"; task energy: %llu nanojoules", _instantaneousInfo.task_energy];
#endif // defined(__arm__) || defined(__arm64__)
    return string;
}

@end

@implementation SentryTaskEventsReading

- (instancetype)initWithError:(NSError *__autoreleasing _Nullable *)error
{
    if ((self = [super init])) {
        task_events_info info;
        mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
        const auto status
            = task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&info, &count);
        if (status != KERN_SUCCESS) {
            if (error) {
                *error = [NSError
                    errorWithDomain:@"io.sentry.error.benchmarking"
                               code:3
                           userInfo:@{
                               NSLocalizedFailureReasonErrorKey : [NSString
                                   stringWithFormat:@"task_info reported an error: %d", status]
                           }];
            }
            return nil;
        }
        _data = info;
    }
    return self;
}

- (NSString *)description
{
    return [NSString
        stringWithFormat:@"faults: %d; pageins: %d; cow_faults: %d; messages_sent: %d; "
                         @"messages_received: %d; syscalls_mach: %d; syscalls_unix: %d; csw: %d",
        _data.faults, _data.pageins, _data.cow_faults, _data.messages_sent, _data.messages_received,
        _data.syscalls_mach, _data.syscalls_unix, _data.csw];
}

@end

@implementation SentryCPUReading

- (instancetype)initWithError:(NSError **)error
{
    if ((self = [super init])) {
        kern_return_t kr;
        mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
        host_cpu_load_info_data_t data;

        kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (int *)&data, &count);
        if (kr != KERN_SUCCESS) {
            if (error) {
                *error =
                    [NSError errorWithDomain:@"io.sentry.error.benchmarking"
                                        code:4
                                    userInfo:@{
                                        NSLocalizedFailureReasonErrorKey : [NSString
                                            stringWithFormat:@"task_info reported an error: %d", kr]
                                    }];
            }
            return nil;
        }

        _systemTicks = data.cpu_ticks[CPU_STATE_SYSTEM];
        _userTicks = data.cpu_ticks[CPU_STATE_USER] + data.cpu_ticks[CPU_STATE_NICE];
        _idleTicks = data.cpu_ticks[CPU_STATE_IDLE];
        _activeProcessorCount = NSProcessInfo.processInfo.activeProcessorCount;
    }
    return self;
}

- (uint64_t)totalTicks
{
    return _systemTicks + _userTicks;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"CPU ticks: %llu; active processors: %lu", [self totalTicks],
                     (unsigned long)_activeProcessorCount];
}

@end

@implementation SentryThreadBasicInfo

- (nonnull instancetype)initForThread:(int)thread
                                error:(NSError *__autoreleasing _Nullable *_Nullable)error
{
    if ((self = [super init])) {
        mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
        thread_basic_info_data_t data;
        // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
        if (thread_info(thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &count)
            == KERN_SUCCESS) {
            const auto threadInfo = [[SentryThreadBasicInfo alloc] init];
            threadInfo.threadInfo = data;
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString
        stringWithFormat:
            @"user time: %llu; system time: %llu; cpu_usage: %d; suspend_count: %d; sleep time: %d",
        microsecondsFromTimeValue(_threadInfo.user_time),
        microsecondsFromTimeValue(_threadInfo.system_time), _threadInfo.cpu_usage,
        _threadInfo.suspend_count, _threadInfo.sleep_time];
}

@end

@implementation SentryScreenReading

- (instancetype)initWithError:(NSError **)error
{
    if ((self = [super init])) {
        UIScreen *screen = UIScreen.mainScreen;
        _displayBrightness = screen.brightness;
        _wantsSoftwareDimming = screen.wantsSoftwareDimming;
        _captured = screen.captured;
    }
    return self;
}

- (NSString *)description
{
    return [NSString
        stringWithFormat:@"screen brightness: %.1f; software dimming: %@; captured: %@",
        _displayBrightness, _wantsSoftwareDimming ? @"YES" : @"NO", _captured ? @"YES" : @"NO"];
}

@end

int sampleCount = 0;

@implementation SentryBenchmarkSample

- (void)writeToFile:(NSString *)cpuEnergyLogPath
             string:(NSString *_Nonnull)string
        prepareFile:(BOOL)prepareFile
{
    int flags = O_RDWR | O_CREAT;
    if (prepareFile) {
        flags |= O_TRUNC;
    } else {
        flags |= O_APPEND;
    }
    const auto benchmarkLog = open(cpuEnergyLogPath.UTF8String, flags, 0644);
    NSAssert(benchmarkLog > 0, @"failed to open file");
    auto result = write(benchmarkLog, string.UTF8String, string.length);
    NSAssert(result > 0, @"failed to write to file");
    result = close(benchmarkLog);
    NSAssert(result == KERN_SUCCESS, @"Failed to close file");
}

- (instancetype)initWithError:(NSError **)error
{
    if ((self = [super init])) {
        _machTime = machTime();
        _threadInfos = cpuInfoByThread();
        _cpuUsagePerCore = cpuUsagePerCore(error);
        _device = [[SentryScreenReading alloc] initWithError:nil];
        _power = [[SentryPowerReading alloc] initWithError:nil];

#if defined(__arm__) || defined(__arm64__)
        static dispatch_once_t onceToken;
        static NSString *cpuEnergyLogPath;
        dispatch_once(&onceToken, ^{
            cpuEnergyLogPath =
                [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                        .firstObject stringByAppendingPathComponent:@"benchmark.csv"];
            const auto string
                = @"Sample,Mach Timestamp,CPU Energy,Task Energy,Screen Brightness,Battery "
                  @"Level,Cumulative CPU Energy,Cumulative Task Energy\n";
            [self writeToFile:cpuEnergyLogPath string:string prepareFile:YES];
        });

        const auto string =
            [NSString stringWithFormat:@"%d,%llu,%llu,%llu,%.2f,%.2f,%llu,%llu,\n", sampleCount++,
                      _machTime, _power.totalInstantaneousCPU, _power.instantaneousInfo.task_energy,
                      _device.displayBrightness, _power.batteryLevel, _power.totalCumulativeCPU,
                      _power.cumulativeInfo.task_energy];
        [self writeToFile:cpuEnergyLogPath string:string prepareFile:NO];
#endif // defined(__arm__) || defined(__arm64__)
    }
    return self;
}

- (NSString *)description
{
    const auto cores = [NSMutableArray array];
    [_cpuUsagePerCore enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { [cores addObject:obj.stringValue]; }];
    return [NSString
        stringWithFormat:@"mach time: %llu;\ndevice info: %@\nThread infos: %@\nCore infos: %@",
        _machTime, _device, _threadInfos, [cores componentsJoinedByString:@", "]];
}

@end

@implementation SentryBenchmarking {
    NSMutableArray<SentryBenchmarkSample *> *samples;

    dispatch_source_t source;
    dispatch_queue_t queue;

    SentryBenchmarkReading *startReading;
}

- (instancetype)init
{
    if ((self = [super init])) {
        samples = [NSMutableArray<SentryBenchmarkSample *> array];

        const auto attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
        const auto leewayNs = intervalNs / 2;
        queue = dispatch_queue_create("io.sentry.benchmark.gcd-scheduler", attr);
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_event_handler(source,
            ^{ [self->samples addObject:[[SentryBenchmarkSample alloc] initWithError:nil]]; });
        dispatch_source_set_timer(
            source, dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, leewayNs);
    }
    return self;
}

+ (instancetype)shared
{
    static SentryBenchmarking *benchmarker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ benchmarker = [[self alloc] init]; });
    return benchmarker;
}

- (void)start
{
    startReading = [[SentryBenchmarkReading alloc] init];
    UIDevice.currentDevice.batteryMonitoringEnabled = YES;

    dispatch_resume(source);
}

- (NSString *)stopAndReturnProfilerThreadUsage
{
    dispatch_cancel(source);

    const NSMutableDictionary<NSString *, SentryThreadBasicInfo *> *aggregatedResults =
        [aggregateCPUUsagePerThread(samples) mutableCopy];
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

- (SentryBenchmarkResult *)stop
{
    dispatch_cancel(source);

    const auto endReading = [[SentryBenchmarkReading alloc] initWithError:nil];

    const auto sampleResult = [[SentrySampledBenchmarkResults alloc] init];
    sampleResult.aggregatedThreadInfo = aggregateCPUUsagePerThread(samples);
    sampleResult.aggregatedCPUUsagePerCore = aggregatedCPUUsagePerCore(samples);
    sampleResult.allSamples = [samples copy];
    const auto result = [[SentryBenchmarkResult alloc] initWithStart:startReading
                                                                 end:endReading
                                              aggregatedSampleResult:sampleResult];

    [samples removeAllObjects];

    return result;
}

+ (uint64_t)machTime
{
    return machTime();
}

@end
