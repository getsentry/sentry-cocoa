// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/tracelogger/src/PacketWriter.h"
#include "cpp/util/src/spimpl.h"

#include <memory>

namespace specto {
template<typename T>
class RingBuffer;

/**
 * A packet writer that writes packets to a ring buffer.
 */
class RingBufferPacketWriter : public PacketWriter {
public:
    /**
     * Constructs a new `RingBufferPacketWriter` that writes to the specified
     * ring buffer.
     *
     * @note The writer will register a new producer for the ring buffer that
     * it will own exclusively. An exception will be thrown if more producers
     * than the number of expected producers is registered.
     *
     * @param buffer The ring buffer to write to.
     */
    explicit RingBufferPacketWriter(std::shared_ptr<RingBuffer<Packet>> buffer);

    RingBufferPacketWriter(const RingBufferPacketWriter &) = delete;
    RingBufferPacketWriter &operator=(const RingBufferPacketWriter &) = delete;
    RingBufferPacketWriter(RingBufferPacketWriter &&) = default;
    RingBufferPacketWriter &operator=(RingBufferPacketWriter &&) = default;

    void write(const PacketWriter::PacketSpec *specs, std::size_t count) override;

private:
    class Impl;
    spimpl::unique_impl_ptr<Impl> impl_;
};

} // namespace specto
