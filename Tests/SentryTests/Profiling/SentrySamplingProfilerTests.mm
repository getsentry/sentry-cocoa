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
    const std::uint32_t samplingRateHz = 300;
    const auto profiler
        = std::make_shared<SamplingProfiler>([](__unused auto backtrace) {}, samplingRateHz);
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
}

@end

#endif
