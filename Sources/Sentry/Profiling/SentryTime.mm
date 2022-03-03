#include "SentryTime.h"

#include <cassert>

#include <CoreFoundation/CFDate.h>
#include <ctime>

namespace sentry {
namespace profiling {
namespace time {

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

} // namespace time
} // namespace profiling
} // namespace sentry
