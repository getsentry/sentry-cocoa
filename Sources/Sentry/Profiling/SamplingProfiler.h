#pragma once

#include <cstdint>
#include <functional>
#include <mach/mach.h>
#include <memory>
#include <mutex>
#include <thread>

@class SentryProfilingEntry;

namespace sentry {
namespace profiling {
    class ThreadMetadataCache;

    /**
     * Samples the stacks on all threads at a specified interval, using the mach clock
     * alarm API for scheduling.
     */
    class SamplingProfiler : public std::enable_shared_from_this<SamplingProfiler> {
    public:
        /**
         * Creates a new sampling profiler that samples at the specified rate.
         * @param callback The callback that is called with each trace entry containing the
         * backtrace for a particular thread. The timestamp of the entry will be set to the
         * timestamp that the sample was collected at.
         * @param measureCost Whether to measure the cost of collecting the backtrace samples.
         * @param samplingRateHz The sampling rate, in Hz, to sample at.
         */
        SamplingProfiler(std::function<void(SentryProfilingEntry *)> callback,
            std::uint32_t samplingRateHz, bool measureCost);

        ~SamplingProfiler();

        /**
         * Starts the sampling profiler.
         * @param onThreadStart A function that is called when the sampling thread starts.
         */
        void startSampling(std::function<void()> onThreadStart = nullptr);

        /** Stops the sampling profiler. */
        void stopSampling();

        /** Returns whether the profiler is currently sampling. */
        bool isSampling();

        /**
         * Returns the number of samples collected. This number will be reset
         * if a new sampling session is started.
         */
        std::uint64_t numSamples();

    private:
        mach_timespec_t delaySpec_;
        std::function<void(SentryProfilingEntry *)> callback_;
        bool measureCost_;
        std::shared_ptr<ThreadMetadataCache> cache_;
        bool isInitialized_;
        std::mutex lock_;
        bool isSampling_;
        std::thread thread_;
        clock_serv_t clock_;
        mach_port_t port_;
        std::atomic_uint64_t numSamples_;
    };
} // namespace profiling
} // namespace sentry
