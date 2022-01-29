#pragma once

#include <cstdint>

namespace specto {
/** Cross-platform threading helpers. */
namespace thread {

    using TIDType = std::uint64_t;

    /** @return Platform-specific thread identifier. */
    TIDType getCurrentTID() noexcept;

} // namespace thread
} // namespace specto
