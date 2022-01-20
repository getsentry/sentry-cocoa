// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Packet.h"

#include <cstddef>
#include <functional>
#include <utility>

#pragma once

namespace specto {

/**
 * An interface for an object that reads `Packet` data structures from a source.
 */
class PacketReader {
public:
    /**
     * Reads packets from the source. This method is overridden by
     * concrete implementations.
     *
     * @param readFunc A function that is called with a pointer to
     * the data buffer to read from and the number of packets to read.
     * The function should return the number of packets that were
     * actually read.
     */
    virtual void
      read(std::function<std::size_t(const Packet *packets, std::size_t count)> readFunc) = 0;

    virtual ~PacketReader() = 0;
};

} // namespace specto
