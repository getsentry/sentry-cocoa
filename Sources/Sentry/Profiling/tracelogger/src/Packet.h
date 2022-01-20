// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "PacketStreamID.h"

#include <cstdint>

namespace specto {

/**
 * A single packet in a stream of packets written to the ring buffer.
 *
 * The data structure is intended to be exactly 128 bytes in size such that it
 * is a multiple of the L1 cache line size. __attribute__((packed)) is used here
 * to disable padding and pack all fields as tightly as possible so we get full
 * control over the alignment.
 *
 * |--------------------|
 * | streamID (4 bytes) |
 * |--------------------|
 * | index (2 bytes)    |
 * |--------------------|
 * | hasNext,           |
 * | size (2 bytes)     |  128 byte packet
 * |--------------------|
 * | data (120 bytes)   |
 * |--------------------|
 */
struct Packet {
    struct __attribute__((packed)) Header {
        /**
         * An identifier shared amongst multiple packets in the same stream.
         */
        PacketStreamID::Type streamID;
        /**
         * The index of the packet within the stream. The first packet in the
         * stream has an index of 0.
         */
        std::uint16_t index;
        /**
         * Whether there are additional packets after this packet in the stream.
         */
        bool hasNext : 1;
        /**
         * The size of the data in the data field.
         */
        std::uint16_t size : 15;
    } header;
    char data[120];
};

static_assert(sizeof(Packet) % 64 == 0,
              "Packet size must be a multiple of the L1 cache line size (64 bytes)");

} // namespace specto
