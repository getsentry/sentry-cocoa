// Copyright (c) Specto Inc. All rights reserved.

#import "BacktracePlugin.h"

#import "cpp/darwin/backtrace/src/SamplingProfiler.h"
#import "cpp/exception/src/Exception.h"
#import "cpp/time/src/Time.h"
#import "spectoproto/entry/entry_generated.pb.h"

#import <chrono>
#import <cstdint>
#import <memory>

namespace specto {
namespace darwin {

BacktracePlugin::BacktracePlugin() = default;

void BacktracePlugin::start(std::shared_ptr<TraceLogger> logger,
                            const std::shared_ptr<proto::TraceConfiguration> &configuration) {
    SPECTO_HANDLE_CPP_EXCEPTION({
        profiler_ = std::make_shared<SamplingProfiler>(
          [logger = std::move(logger)](auto entry) {
              // Perform the same timestamp transformation that TraceLogger::log() does
              const auto timeSinceReference = time::getDurationNs(
                logger->referenceUptimeNs(), entry->elapsed_relative_to_start_date_ns());
              entry->set_elapsed_relative_to_start_date_ns(timeSinceReference.count());
              const auto size = entry->ByteSizeLong();
              char buf[size];
              if (entry->SerializeToArray(buf, static_cast<int>(size))) {
                  // Use unsafeLogBytes directly instead of log to avoid creating a copy of the
                  // proto::Entry.
                  logger->unsafeLogBytes(buf, size);
              } else {
                  SPECTO_LOG_ERROR("Failed to serialize entry to byte array.");
              }
          },
          configuration->backtrace().sampling_rate_hz(),
          configuration->measure_cost());
        profiler_->startSampling();
    });
}

void BacktracePlugin::end(__unused std::shared_ptr<TraceLogger> logger) {
    stopCollecting();
}

void BacktracePlugin::abort(__unused const proto::Error &error) {
    stopCollecting();
}

void BacktracePlugin::stopCollecting() {
    SPECTO_HANDLE_CPP_EXCEPTION({
        profiler_->stopSampling();
        profiler_ = nullptr;
    });
}

bool BacktracePlugin::shouldEnable(
  const std::shared_ptr<proto::TraceConfiguration> &configuration) const {
// Disable backtrace collection when running with TSAN because it produces a TSAN false
// positive, similar to the situation described here:
// https://github.com/envoyproxy/envoy/issues/2561
#if defined(__has_feature)
#if __has_feature(thread_sanitizer)
    SPECTO_LOG_INFO("Disabling backtrace collection because TSAN is enabled.");
    return false;
#endif
#endif
    return configuration->backtrace().enabled();
}

} // namespace darwin
} // namespace specto
