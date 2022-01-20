// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/darwin/backtrace/src/SamplingProfiler.h"
#include "cpp/darwin/backtrace/src/ThreadMetadataCache.h"
#include "cpp/exception/src/Exception.h"
#include "cpp/time/src/Time.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <chrono>
#include <iostream>
#include <pthread.h>
#include <thread>

using namespace specto;
using namespace specto::darwin;

class SamplingProfilerTest : public ::testing::Test {
protected:
    void SetUp() override {
        internal::setCppExceptionKillswitch(false);
    }
};

TEST_F(SamplingProfilerTest, TestMaintains300HzRate) {
    const auto cache = std::make_shared<ThreadMetadataCache>();
    const std::uint32_t samplingRateHz = 300;
    const auto profiler =
      std::make_shared<SamplingProfiler>([](__unused auto entry) {}, samplingRateHz);
    EXPECT_FALSE(profiler->isSampling());

    time::Type start = 0;
    profiler->startSampling([&start] { start = time::getUptimeNs(); });
    EXPECT_TRUE(profiler->isSampling());

    std::this_thread::sleep_for(std::chrono::seconds(3));
    profiler->stopSampling();

    EXPECT_FALSE(profiler->isSampling());

    const auto duration = time::getDurationNs(start);
    EXPECT_GT(start, 0);
    EXPECT_GT(std::chrono::duration_cast<std::chrono::seconds>(duration).count(), 0);
#if !defined(SPECTO_CI_ENVIRONMENT)
    // Allow 15% loss in the number of samples.
    EXPECT_GE(profiler->numSamples(),
              samplingRateHz * std::chrono::duration_cast<std::chrono::seconds>(duration).count()
                * 0.85);
#else
    // CI is too slow to set expectations for how many samples will be collected.
    EXPECT_GT(profiler->numSamples(), 0);
#endif
}

TEST_F(SamplingProfilerTest, TestRaisingExceptionCallsStopSampling) {
    const auto profiler = std::make_shared<SamplingProfiler>([](__unused auto entry) {}, 100);
    profiler->startSampling();
    EXPECT_TRUE(profiler->isSampling());

    SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION(
      { throw std::runtime_error("A wild exception appeared"); });

    EXPECT_FALSE(profiler->isSampling());
}
