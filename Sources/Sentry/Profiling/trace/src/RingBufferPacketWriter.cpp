// Copyright (c) Specto Inc. All rights reserved.

#include "RingBufferPacketWriter.h"

#include "cpp/log/src/Log.h"
#include "cpp/ringbuffer/src/RingBuffer.h"

#include <cassert>
#include <utility>

// In case we want to implement retry later, instead of just dropping:
//
// #include <chrono>
// #include <random>
//
// namespace {
// std::chrono::milliseconds jitteredExponentialBackoffDuration(int n) {
//     thread_local static std::random_device rd;
//     thread_local static std::mt19937 gen(rd());
//     std::uniform_real_distribution<> dist(0.0, 50.0); // up to 50ms jitter
//     const auto duration = static_cast<std::chrono::milliseconds::rep>(
//       std::min(20.0 /* 20ms minimum */ * std::pow(2, n) + dist(gen), 200.0 /* 200ms maximum */));
//     return std::chrono::milliseconds(duration);
// }
// } // namespace

namespace specto {

class RingBufferPacketWriter::Impl {
public:
    explicit Impl(const std::shared_ptr<RingBuffer<Packet>> &buffer) :
        ringbuffer_(buffer), producer_((buffer != nullptr) ? buffer->registerProducer() : nullptr) {
    }

    void write(const PacketWriter::PacketSpec *specs, std::size_t count) {
        assert(specs != nullptr);
        if (producer_ == nullptr) {
            SPECTO_LOG_ERROR(
              "Not writing to ring buffer because the producer could not be created");
            return;
        }
        const auto success = producer_->produce(count, [specs](Packet *data, std::size_t c) {
            const auto buf = reinterpret_cast<char *>(data);
            for (decltype(c) i = 0; i < c; i++) {
                const auto spec = &specs[i];
                const auto offsetPtr = buf + (i * sizeof(Packet));
                std::memcpy(offsetPtr, &spec->header, sizeof(spec->header));
                std::memcpy(offsetPtr + sizeof(spec->header), spec->data, spec->header.size);
            }
        });
        if (!success) {
            ringbuffer_->incrementDropCounter();
        }
    }

private:
    std::shared_ptr<RingBuffer<Packet>> ringbuffer_;
    std::unique_ptr<RingBuffer<Packet>::Producer> producer_;
};

RingBufferPacketWriter::RingBufferPacketWriter(std::shared_ptr<RingBuffer<Packet>> buffer) :
    impl_(spimpl::make_unique_impl<Impl>(buffer)) { }

void RingBufferPacketWriter::write(const PacketSpec *specs, std::size_t count) {
    impl_->write(specs, count);
}

} // namespace specto
