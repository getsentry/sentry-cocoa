#import "SentryBenchmarking.h"
#include <chrono>
#include <mach/clock.h>
#include <mach/mach.h>
#include <pthread.h>
#include <string>
#import <thread>

#define SENTRY_BENCHMARK_GCD_BASED
//#define SENTRY_BENCHMARK_NSTHREAD_BASED
//#define SENTRY_BENCHMARK_PTHREAD_BASED

#define SENTRY_BENCHMARKING_THREAD_NAME "io.sentry.benchmark.sampler-thread"

namespace {
/// @note: Implementation ported from @c SentryThreadHandle.hpp .
NSDictionary<NSString *, NSArray<NSNumber *> *> *
cpuInfoByThread()
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

bool cancel_ = false;

NSMutableArray<NSDictionary<NSString *, NSArray<NSNumber *> *> *> *samples =
    [NSMutableArray<NSDictionary<NSString *, NSArray<NSNumber *> *> *> array];

// MARK: GCD-based approach

dispatch_source_t source;
dispatch_queue_t queue;

void
gcdBasedApproach()
{
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

// MARK: pthread-based approach

void
samplingThreadCleanup(void *buf)
{
    free(buf);
}

void *
benchmarkingSamplingThreadMain(mach_port_t port, clock_serv_t clock, mach_timespec_t delaySpec)
{
    assert(pthread_setname_np(SENTRY_BENCHMARKING_THREAD_NAME) == KERN_SUCCESS);
    const int maxSize = 512;
    const auto bufRequest = reinterpret_cast<mig_reply_error_t *>(malloc(maxSize));
    pthread_cleanup_push(samplingThreadCleanup, bufRequest);
    while (true) {
        pthread_testcancel();
        if (mach_msg(&bufRequest->Head, MACH_RCV_MSG, 0, maxSize, port, MACH_MSG_TIMEOUT_NONE,
                MACH_PORT_NULL)
            != MACH_MSG_SUCCESS) {
            break;
        }
        if (clock_alarm(clock, TIME_RELATIVE, delaySpec, port) != KERN_SUCCESS) {
            break;
        }

        [samples addObject:cpuInfoByThread()];
    }
    pthread_cleanup_pop(1);
    return nullptr;
}

mach_timespec_t delaySpec_;
std::thread thread_;
clock_serv_t clock_;
mach_port_t port_;
void
pthreadBasedApproach()
{
    assert(host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &clock_) == KERN_SUCCESS);
    assert(mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port_) == KERN_SUCCESS);
    const auto intervalNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::duration<float>(1) / frequencyHz)
                                .count();
    delaySpec_ = { .tv_sec = static_cast<unsigned int>(intervalNs / 1000000000ULL),
        .tv_nsec = static_cast<clock_res_t>(intervalNs % 1000000000ULL) };
    thread_ = std::thread(benchmarkingSamplingThreadMain, port_, clock_, delaySpec_);

    int policy;
    sched_param param;
    const auto pthreadHandle = thread_.native_handle();
    if (pthread_getschedparam(pthreadHandle, &policy, &param) == KERN_SUCCESS) {
        // A priority of 50 is higher than user input, according to:
        // https://chromium.googlesource.com/chromium/src/base/+/master/threading/platform_thread_mac.mm#302
        // Run at a higher priority than the main thread so that we can capture main thread
        // backtraces even when it's busy.
        param.sched_priority = 50;
        assert(pthread_setschedparam(pthreadHandle, policy, &param) == KERN_SUCCESS);
    }

    assert(clock_alarm(clock_, TIME_RELATIVE, delaySpec_, port_) == KERN_SUCCESS);
}

// MARK: NSThread based approach

NSThread *thread;
void
nsthreadBasedApproach()
{
    thread = [[NSThread alloc] initWithBlock:^{
        assert(pthread_setname_np(SENTRY_BENCHMARKING_THREAD_NAME) == KERN_SUCCESS);
        while (true) {
            if (cancel_) {
                break;
            }
            [samples addObject:cpuInfoByThread()];
            [NSThread sleepForTimeInterval:1.0 / frequencyHz];
        }
    }];
    thread.name = @SENTRY_BENCHMARKING_THREAD_NAME;
    thread.qualityOfService = NSQualityOfServiceUserInteractive;
    [thread start];
}
}

@implementation SentryBenchmarking

+ (void)startBenchmarkProfile
{
    cancel_ = false;

#if defined(SENTRY_BENCHMARK_GCD_BASED)
    gcdBasedApproach();
#elif defined(SENTRY_BENCHMARK_PTHREAD_BASED)
    pthreadBasedApproach();
#elif defined(SENTRY_BENCHMARK_NSTHREAD_BASED)
    nsthreadBasedApproach();
#endif
}

+ (double)retrieveBenchmarks
{
#if defined(SENTRY_BENCHMARK_GCD_BASED)
    dispatch_cancel(source);
#elif defined(SENTRY_BENCHMARK_PTHREAD_BASED)
    assert(pthread_cancel(thread_.native_handle()) == KERN_SUCCESS);
    thread_.join();
#elif defined(SENTRY_BENCHMARK_NSTHREAD_BASED)
    [thread cancel];
#endif

    [samples addObject:cpuInfoByThread()];

    if (samples.count < 2) {
        return -1;
    }

    const auto totals = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto cpuUsages = [NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> dictionary];
    for (auto i = 0; i < samples.count - 2; i++) {
        const auto before = samples[i];
        const auto after = samples[i + 1];

        void(^cpuUsageConsumer)(NSString * _Nonnull, NSArray<NSNumber *> * _Nonnull, BOOL * _Nonnull) = ^(NSString * _Nonnull key, NSArray<NSNumber *> * _Nonnull obj, BOOL * _Nonnull stop) {
            if (![key isEqualToString:@"io.sentry.SamplingProfiler"]) {
                return;
            }

            if (cpuUsages[key]) {
                [cpuUsages[key] addObject:obj[2]];
            } else {
                cpuUsages[key] = [@[obj[2]] mutableCopy];
            }
        };

        [before enumerateKeysAndObjectsUsingBlock:cpuUsageConsumer];
        if (i == samples.count - 3) {
            [after enumerateKeysAndObjectsUsingBlock:cpuUsageConsumer];
        }

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
            if (thisSystemTime + thisUserTime < lastSystemTime + lastUserTime) {
                // thread id was reassigned to a new thread since last sample
                [destroyedThreads addObject:key];
                continue;
            }
            const auto thisDelta = thisSystemTime + thisUserTime - lastSystemTime - lastUserTime;
            if (!totals[key]) {
                totals[key] = @(thisDelta);
            } else {
                totals[key] = @(thisDelta + totals[key].integerValue);
            }
        }
    }

    [samples removeAllObjects];

    return [[cpuUsages[@"io.sentry.SamplingProfiler"] valueForKeyPath:@"@avg.self"] doubleValue] / TH_USAGE_SCALE * 100.0;
}

@end
