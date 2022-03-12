#import <XCTest/XCTest.h>

#import "SentryBacktrace.hpp"
#import "SentryThreadMetadataCache.hpp"
#import "SentrySamplingProfiler.hpp"

#import <chrono>
#import <ctime>
#import <iostream>
#import <pthread.h>
#import <thread>

using namespace sentry::profiling;

@interface SentrySamplingProfilerTests : XCTestCase
@end

@implementation SentrySamplingProfilerTests

- (void)testProfiling {
    const auto cache = std::make_shared<ThreadMetadataCache>();
    const std::uint32_t samplingRateHz = 300;
    const auto profiler =
      std::make_shared<SamplingProfiler>([](__unused auto backtrace) {}, samplingRateHz);
    XCTAssertFalse(profiler->isSampling());

    std::uint64_t start = 0;
    profiler->startSampling([&start] { start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW); });
    XCTAssertTrue(profiler->isSampling());

    std::this_thread::sleep_for(std::chrono::seconds(3));
    profiler->stopSampling();

    XCTAssertFalse(profiler->isSampling());

    const auto duration = std::chrono::nanoseconds(clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start);
    XCTAssertGreaterThan(start, static_cast<std::uint64_t>(0));
    XCTAssertGreaterThan(std::chrono::duration_cast<std::chrono::seconds>(duration).count(), 0);
    XCTAssertGreaterThan(profiler->numSamples(), static_cast<std::uint64_t>(0));
}

@end
