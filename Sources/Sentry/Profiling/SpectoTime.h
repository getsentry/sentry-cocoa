#pragma once

#include <chrono>
#include <cstdint>
#include <functional>

namespace sentry {
namespace profiling {
namespace time {

    using Type = std::uint64_t;

    /** @return Device uptime. */
    Type getUptimeNs() noexcept;

    /** @return Time between two absolute timestamps, in nano-seconds. */
    std::chrono::nanoseconds getDurationNs(Type fromNs, Type toNs = getUptimeNs()) noexcept;

    /** @return Seconds since UNIX epoch. */
    std::chrono::seconds getSecondsSinceEpoch() noexcept;

} // namespace time
} // namespace profiling
} // namespace sentry
