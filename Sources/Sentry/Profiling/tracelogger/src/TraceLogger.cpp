// Copyright (c) Specto Inc. All rights reserved.

#include "TraceLogger.h"

#include "Packet.h"
#include "PacketStreamID.h"
#include "PacketWriter.h"
#include "Log.h"

#include <atomic>
#include <cassert>
#include <cstdint>
#include <type_traits>

namespace specto {

TraceLogger::TraceLogger(std::shared_ptr<PacketWriter> writer,
                         time::Type referenceUptimeNs,
                         std::function<void(void)> onLog) :
    writer_(std::move(writer)),
    referenceUptimeNs_(referenceUptimeNs), onLog_(std::move(onLog)) {
    assert(writer_ != nullptr);
}

void TraceLogger::log(specto::proto::Entry entry) const {
    const auto timestampRelativeToUptimeNs = entry.elapsed_relative_to_start_date_ns();
    // A specific event could have started before the logger has been created and finished
    // while the logger exists. In this case, we need to ignore the entry.
    // An example of such an entry is a network request.
    if (timestampRelativeToUptimeNs < referenceUptimeNs_) {
        SPECTO_LOG_TRACE(
          "The entry being logged has a start date before the trace start and will be discarded.");
        return;
    }

    entry.set_elapsed_relative_to_start_date_ns(time::getDurationNs(referenceUptimeNs_, timestampRelativeToUptimeNs).count());

    const auto size = entry.ByteSizeLong();
    if (size > kMaxEntrySize) {
        SPECTO_LOG_ERROR("Entry (type: {}) size exceeds the maximum size of 1024 bytes",
                         proto::Entry_Type_Name(entry.type()));
        return;
    }
    char buf[size];
    if (!entry.SerializeToArray(buf, size)) {
        SPECTO_LOG_ERROR("Failed to serialize entry to byte array.");
        return;
    }
    auto writer = std::atomic_load_explicit(&writer_, std::memory_order_acquire);
    if (writer == nullptr) {
        SPECTO_LOG_DEBUG("Attempting to log to an invalidated trace logger with entry type: {}",
                         proto::Entry_Type_Name(entry.type()));
        return;
    }
    write(buf, size, writer);
}

void TraceLogger::unsafeLogBytes(const char *buf, std::size_t size) const {
    auto writer = std::atomic_load_explicit(&writer_, std::memory_order_acquire);
    if (writer == nullptr) {
        SPECTO_LOG_DEBUG("Attempting to log to an invalidated trace logger.");
        return;
    }
    write(buf, size, writer);
}

void TraceLogger::write(const char *buf,
                        std::size_t size,
                        const std::shared_ptr<PacketWriter> &writer) const {
    const auto id = PacketStreamID::getNext();
    const auto packetCount = (size + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    PacketWriter::PacketSpec specs[packetCount];

    std::remove_const<decltype(size)>::type offset = 0;
    std::uint16_t packetIndex = 0;

    while (offset < size) {
        const auto remainingSize = size - offset;
        const std::uint16_t writeSize = std::min(sizeof(Packet::data), remainingSize);

        specs[packetIndex] = PacketWriter::PacketSpec {
          .header =
            {
              .streamID = id,
              .index = packetIndex,
              .hasNext = remainingSize > sizeof(Packet::data),
              .size = writeSize,
            },
          .data = &buf[offset],
        };
        offset += writeSize;
        packetIndex++;
    }

    writer->write(specs, packetCount);
    if (onLog_ != nullptr) {
        onLog_();
    }
}

void TraceLogger::invalidate() {
    std::atomic_store_explicit(
      &writer_, std::shared_ptr<PacketWriter> {}, std::memory_order_release);
}

time::Type TraceLogger::referenceUptimeNs() const {
    return referenceUptimeNs_;
}

} // namespace specto
