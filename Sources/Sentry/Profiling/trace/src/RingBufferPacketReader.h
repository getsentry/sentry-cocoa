// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "PacketReader.h"

#include <memory>
#include <utility>

namespace specto {
template<typename T>
class RingBuffer;

/**
 * A packet writer that reads packets from a ring buffer.
 */
class RingBufferPacketReader : public PacketReader {
public:
    /**
     * Constructs a new `RingBufferPacketReader` that reads from the specified
     * ring buffer.
     *
     * @note `RingBuffer` only supports a single consumer, so there should only
     * ever be a single `RingBufferPacketReader` reading from the buffer at any
     * given time.
     *
     * @param buffer The ring buffer to read from.
     */
    explicit RingBufferPacketReader(std::shared_ptr<RingBuffer<Packet>> buffer);

    RingBufferPacketReader(const RingBufferPacketReader &) = delete;
    RingBufferPacketReader &operator=(const RingBufferPacketReader &) = delete;
    RingBufferPacketReader(RingBufferPacketReader &&) = default;
    RingBufferPacketReader &operator=(RingBufferPacketReader &&) = default;

    void
      read(std::function<std::size_t(const Packet *packets, std::size_t count)> readFunc) override;

private:
    std::shared_ptr<RingBuffer<Packet>> buffer_;
};

} // namespace specto
