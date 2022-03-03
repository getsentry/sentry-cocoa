#pragma once

#include <cstdint>

namespace sentry {
namespace profiling {
namespace thread {

using TIDType = std::uint64_t;

/** @return Platform-specific thread identifier. */
TIDType getCurrentTID() noexcept;

} // namespace thread
} // namespace profiling
} // namespace sentry
