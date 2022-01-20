// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <atomic>
#include <cstdint>

namespace specto {

/**
 * Generates IDs that are used to identify packets belonging to the same data stream.
 */
struct PacketStreamID {
    using Type = std::uint32_t;

    PacketStreamID() = delete;

    /**
     * Increments the stream ID and returns it.
     */
    static Type getNext() noexcept;
    /**
     * Reset the stream ID back to its initial value.
     */
    static void reset() noexcept;

private:
    static std::atomic<Type> streamID_;
};

} // namespace specto
