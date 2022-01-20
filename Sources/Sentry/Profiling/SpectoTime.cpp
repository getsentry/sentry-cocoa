// Copyright (c) Specto Inc. All rights reserved.

#include "SpectoTime.h"

#include <cassert>

#ifdef __ANDROID__

#include <ctime>
#include <time.h>

namespace specto {
namespace time {

constexpr std::uint64_t kNanosecondsInSeconds = 1000000000;

Type getUptimeNs() noexcept {
    struct timespec now;
    // Using CLOCK_BOOTTIME to be in sync with SystemClock.elapsedRealtimeNanos() in Java.
    clock_gettime(CLOCK_BOOTTIME, &now);
    return static_cast<std::uint64_t>(now.tv_sec) * kNanosecondsInSeconds + now.tv_nsec;
}

std::chrono::nanoseconds getDurationNs(std::uint64_t fromNs, std::uint64_t toNs) noexcept {
    assert(toNs >= fromNs);
    return std::chrono::nanoseconds(toNs - fromNs);
}

std::chrono::seconds getSecondsSinceEpoch() noexcept {
    return std::chrono::seconds(static_cast<std::uint64_t>(std::time(nullptr)));
}

} // namespace time
} // namespace specto

#elif __APPLE__

#include <CoreFoundation/CFDate.h>
#include <ctime>

namespace specto::time {

Type getUptimeNs() noexcept {
    return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}

std::chrono::nanoseconds getDurationNs(std::uint64_t fromNs, std::uint64_t toNs) noexcept {
    assert(toNs >= fromNs);
    return std::chrono::nanoseconds(toNs - fromNs);
}

std::chrono::seconds getSecondsSinceEpoch() noexcept {
    return std::chrono::seconds(
      static_cast<std::uint64_t>(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970));
}

} // namespace specto::time

#endif
