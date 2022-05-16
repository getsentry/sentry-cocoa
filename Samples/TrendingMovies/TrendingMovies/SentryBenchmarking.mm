#import "SentryBenchmarking.h"
#include <pthread.h>
#include <mach/mach.h>
#include <chrono>
#include <string>

namespace {
    /// @note: Implementation ported from @c SentryThreadHandle.hpp .
    NSDictionary<NSNumber *, NSNumber *> *threadCPUTimes() {
        const auto dict = [NSMutableDictionary<NSNumber *, NSNumber *> dictionary];
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
                namestr = std::string(name);
                printf("***thread name: %s\n", namestr.c_str()); // TODO: remove before merging

                // we're only interested in work on the main thread and the profiling thread
                if (thread != mainThreadID && namestr != "io.sentry.SamplingProfiler") {
                    continue;
                }

                mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
                thread_basic_info_data_t data;
                // MACH_SEND_INVALID_DEST is returned when the thread no longer exists
                if (thread_info(thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &count) == KERN_SUCCESS) {
                    const auto systemTime_micros = data.system_time.seconds * 1e6 + data.system_time.microseconds + data.user_time.seconds * 1e6 + data.user_time.microseconds;
                    dict[@(thread)] = @(systemTime_micros);
                }
            }
        }
        vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
        return dict;
    }

    NSDictionary<NSNumber *, NSNumber *> *before;
}

@implementation SentryBenchmarking

+ (void)startBenchmarkProfile {
    before = threadCPUTimes();
}

+ (uint64_t)retrieveBenchmarks {
    const auto after = threadCPUTimes();
    const auto afterKeys = [NSSet<NSNumber *> setWithArray:after.allKeys];
    const auto beforeKeys = [NSMutableSet<NSNumber *> setWithArray:before.allKeys];
    [beforeKeys intersectSet:afterKeys];
    auto delta = 0;

    /// TODO: debugging; remove before merging
    const auto threadsOfInterest = [NSMutableDictionary<NSNumber *, NSArray<NSNumber *> *> dictionary];
    for (NSNumber *key : beforeKeys) {
        threadsOfInterest[key] = @[before[key], after[key]];
    }
    printf("threads of interest: %s\n", threadsOfInterest.description.UTF8String);

    for (NSNumber *key : beforeKeys) {
        const auto thisDelta = after[key].integerValue - before[key].integerValue;
        printf("before: %ld; after: %ld; delta: %ld\n", (long)before[key].integerValue, after[key].integerValue, thisDelta);
        delta += thisDelta;
    }
    return delta;
}

@end
