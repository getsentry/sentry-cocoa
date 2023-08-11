#import "SentryBenchmarking.h"
#include <chrono>
#include <mach/clock.h>
#include <mach/mach.h>
#import <mach/mach_time.h>
#include <pthread.h>
#include <string>
#import <sys/sysctl.h>
#import <thread>

#define SENTRY_BENCHMARK_GCD_BASED

#define SENTRY_BENCHMARKING_THREAD_NAME "io.sentry.benchmark.sampler-thread"

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

NSMutableArray<NSDictionary<NSString *, NSArray<NSNumber *> *> *> *samples =
    [NSMutableArray<NSDictionary<NSString *, NSArray<NSNumber *> *> *> array];

dispatch_source_t source;
dispatch_queue_t queue;

uint64_t startTime;
}

@implementation SentryBenchmarking

+ (void)startBenchmark
{
    startTime = mach_absolute_time();
    const auto attr = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    const auto leewayNs = intervalNs / 2;
    queue = dispatch_queue_create("io.sentry.benchmark.gcd-scheduler", attr);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_event_handler(source, ^{ [samples addObject:cpuInfoByThread()]; });
    dispatch_source_set_timer(
        source, dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, leewayNs);
    dispatch_resume(source);
}

+ (NSString *)stopBenchmark
{
    const auto endTime = mach_absolute_time();
    dispatch_cancel(source);

    [samples addObject:cpuInfoByThread()];

    if (samples.count < 2) {
        printf("[Sentry Benchmark] not enough samples were gathered to compute CPU usage.\n");
        return nil;
    }

    const auto systemTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto userTimeTotals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto cpuUsages = [NSMutableArray<NSNumber *> array];
    for (auto i = 0; i < samples.count - 2; i++) {
        const auto before = samples[i];
        const auto after = samples[i + 1];

        const auto afterKeys = [NSSet<NSString *> setWithArray:after.allKeys];
        const auto persistedThreads = [NSMutableSet<NSString *> setWithArray:before.allKeys];
        [persistedThreads intersectSet:afterKeys];
        const auto destroyedThreads = [NSMutableSet<NSString *> setWithArray:before.allKeys];
        [destroyedThreads minusSet:persistedThreads];

        for (NSString *key : persistedThreads) {
            const auto lastSystemTime = before[key][0].integerValue;
            const auto thisSystemTime = after[key][0].integerValue;
            const auto lastUserTime = before[key][1].integerValue;
            const auto thisUserTime = after[key][1].integerValue;
            const auto thisCPUUsage = after[key][2].floatValue;
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
            if ([key isEqualToString:@"io.sentry.SamplingProfiler"]) {
                [cpuUsages addObject:@(thisCPUUsage)];
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

    const auto profilerTotalTicks = profilerSystemTime + profilerUserTime;
    const auto wallClockDurationSec = (endTime - startTime) / 1e9;
    const auto workRateHz = profilerTotalTicks / wallClockDurationSec;

    uint32_t clockRateHz = 0;
    size_t size = sizeof(clockRateHz);
    int mib[2];
    mib[0] = CTL_HW;
    mib[1] = KERN_CLOCKRATE;
    sysctl(mib, 2, &clockRateHz, &size, NULL, 0);

    const auto percentage = workRateHz / clockRateHz * 100.f;

    NSLog(@"percentage: %f", percentage);

    return [NSString stringWithFormat:@"%ld,%ld,%ld,%ld", profilerSystemTime, profilerUserTime,
                     appSystemTime, appUserTime];
}

@end
