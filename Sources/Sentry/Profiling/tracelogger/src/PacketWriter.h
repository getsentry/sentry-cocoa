// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Packet.h"

#include <cstddef>

namespace specto {

/**
 * An interface for an object that writes `Packet` data structures to a destination.
 */
class PacketWriter {
public:
    /**
     * An alternate representation of a `Packet` that allows for implementing
     * optimizations to avoid unnecessary memory copying. The packet writer can
     * copy data directly from the pointer specified in the spec rather than
     * having to copy data into a `Packet` before passing it to the packet writer.
     *
     * The `data` buffer must have a size >= to `header.size`.
     */
    struct PacketSpec {
        Packet::Header header;
        const char *data;
    };

    /**
     * Writes packets to the destination. This method is overridden
     * by concrete implementations.
     *
     * @param specs Pointer to the array of packet specs representing the
     * packets to write.
     * @param count The number of packets to write.
     */
    virtual void write(const PacketSpec *specs, std::size_t count) = 0;

    virtual ~PacketWriter() = 0;
};

} // namespace specto
