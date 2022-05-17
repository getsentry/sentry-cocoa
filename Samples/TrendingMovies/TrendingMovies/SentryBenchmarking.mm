#import "SentryBenchmarking.h"
#include <pthread.h>
#include <mach/mach.h>
#include <chrono>
#include <string>
#    import <thread>
#    include <mach/clock.h>

namespace {
/// @note: Implementation ported from @c SentryThreadHandle.hpp .
NSDictionary<NSString *, NSNumber *> *cpuInfoByThread() {
    const auto dict = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    mach_msg_type_number_t count;
    thread_act_array_t list;

    if (task_threads(mach_task_self(), &list, &count) == KERN_SUCCESS) {
        const auto mainThreadID = pthread_mach_thread_np(pthread_self());
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
            if (thread == mainThreadID) {
                namestr = "main";
            } else {
                namestr = std::string(name);
                if (namestr.length() == 0) {
                    namestr = std::to_string(thread);
                }
            }

            mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
            thread_basic_info_data_t data;
            // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
            if (thread_info(thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &count) == KERN_SUCCESS) {
                const auto time_micros = data.system_time.seconds * 1e6 + data.system_time.microseconds + data.user_time.seconds * 1e6 + data.user_time.microseconds;
                dict[[NSString stringWithUTF8String:namestr.c_str()]] = @(time_micros);
            }
        }
    }
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
    return dict;
}

NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *samples = [NSMutableArray<NSDictionary<NSString *, NSNumber *> *> array];

dispatch_source_t source;
dispatch_queue_t queue;
}

@implementation SentryBenchmarking

+ (void)startBenchmarkProfile {
    const auto attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    const auto frequencyHz = 10;
    const auto intervalNs = 1e9 / frequencyHz;
    const auto leewayNs = intervalNs / 2;
    queue = dispatch_queue_create("io.sentry.benchmarking.gcd-scheduler", attr);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_event_handler(source, ^{
        [samples addObject:cpuInfoByThread()];
    });
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, leewayNs);
    dispatch_resume(source);
}

+ (double)retrieveBenchmarks {
    [samples addObject:cpuInfoByThread()];
    const auto totals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    for (auto i = 0; i < samples.count - 2; i++) {
        const auto before = samples[i];
        const auto after = samples[i + 1];

        const auto afterKeys = [NSSet<NSString *> setWithArray:after.allKeys];
        const auto persistedThreads = [NSMutableSet<NSString *> setWithArray:before.allKeys];
        [persistedThreads intersectSet:afterKeys];
        const auto destroyedThreads = [NSMutableSet<NSString *> setWithArray:before.allKeys];
        [destroyedThreads minusSet:persistedThreads];

        printf("%lu destroyed threads\n", (unsigned long)destroyedThreads.count);

        for (NSString *key : persistedThreads) {
            const auto lastSampleValue = before[key].integerValue;
            const auto thisSampleValue = after[key].integerValue;
            if (thisSampleValue < lastSampleValue) {
                // thread id was reassigned to a new thread since last sample
                [destroyedThreads addObject:key];
                continue;
            }
            const auto thisDelta = thisSampleValue - lastSampleValue;
            printf("before: %ld; after: %ld; delta: %ld\n", (long)before[key].integerValue, after[key].integerValue, thisDelta);
            if (!totals[key]) {
                totals[key] = @(thisDelta);
            } else {
                totals[key] = @(thisDelta + totals[key].integerValue);
            }
        }

        // extrapolate to estimate the remaining work done by a thread that's destroyed before this sample?
//        for (NSString *key : destroyedThreads) {
//            const auto thisDelta = before[key].integerValue;
//            if (!totals[key]) {
//                totals[key] = @(thisDelta);
//            } else {
//                totals[key] = @(thisDelta + totals[key].integerValue);
//            }
//        }
    }

    const auto samplingThreadUsage = totals[@"io.sentry.SamplingProfiler"].integerValue;
    const auto totalUsage = ((NSNumber *)[totals.allValues valueForKeyPath:@"@sum.self"]).integerValue;

    return 100.0 * samplingThreadUsage / totalUsage;
}

@end
