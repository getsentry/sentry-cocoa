#pragma once

namespace sentry {
namespace profiling {
    /** Test if the specified memory is safe to read from.
     *
     * @param memory A pointer to the memory to test.
     * @param byteCount The number of bytes to test.
     *
     * @return True if the memory can be safely read.
     */
    bool isMemoryReadable(const void *const memory, const int byteCount);
} // namespace profiling
} // namespace sentry
