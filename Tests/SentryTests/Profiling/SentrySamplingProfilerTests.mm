#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <XCTest/XCTest.h>

#    import "SentryBacktrace.hpp"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryThreadMetadataCache.hpp"
#    import "SentryTime.h"

#    import <chrono>
#    import <iostream>
#    import <pthread.h>
#    import <thread>

using namespace sentry::profiling;

@interface SentrySamplingProfilerTests : XCTestCase
@end

@implementation SentrySamplingProfilerTests

- (void)testProfiling
{
    const auto cache = std::make_shared<ThreadMetadataCache>();
    const std::uint32_t samplingRateHz = 301;

    pthread_t idleThread;
    XCTAssertEqual(pthread_create(&idleThread, nullptr, idleThreadEntry, nullptr), 0);
    int numIdleSamples = 0;

    const auto profiler = std::make_shared<SamplingProfiler>(
        [&](auto &backtrace) {
            const auto thread = backtrace.threadMetadata.threadID;
            if (thread == pthread_mach_thread_np(idleThread)) {
                numIdleSamples++;
            }
        },
        samplingRateHz);
    XCTAssertFalse(profiler->isSampling());

    std::uint64_t start = 0;
    profiler->startSampling([&start] { start = getAbsoluteTime(); });
    XCTAssertTrue(profiler->isSampling());

    std::this_thread::sleep_for(std::chrono::seconds(3));
    profiler->stopSampling();

    XCTAssertFalse(profiler->isSampling());

    const auto duration = std::chrono::nanoseconds(getDurationNs(start, getAbsoluteTime()));
    XCTAssertGreaterThan(start, static_cast<std::uint64_t>(0));
    XCTAssertGreaterThan(std::chrono::duration_cast<std::chrono::seconds>(duration).count(), 0);
    XCTAssertGreaterThan(profiler->numSamples(), static_cast<std::uint64_t>(0));
    XCTAssertGreaterThan(numIdleSamples, 0);

    // end the test idle thread
    XCTAssertEqual(pthread_cancel(idleThread), 0);
    XCTAssertEqual(pthread_join(idleThread, nullptr), 0);
}

static void *
idleThreadEntry(__unused void *ptr)
{
    pthread_testcancel();

    // Wait on a condition variable that will never be signaled to make the thread idle.
    pthread_cond_t cv;
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    if (pthread_cond_init(&cv, NULL) != 0) {
        return nullptr;
    }
    if (pthread_cond_wait(&cv, &mutex) != 0) {
        return nullptr;
    }
    return nullptr;
}

@end

#endif
