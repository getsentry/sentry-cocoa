// Copyright (c) Specto Inc. All rights reserved.

#pragma once

// clang-format off

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <stdexcept>
#include <cstdlib>
#include <sys/types.h>
#include <unistd.h>

#include "Log.h"
#include "external/com_github_rmind_ringbuf/src/ringbuf.h"

// clang-format on

namespace specto {
/**
 * C++ wrapper for the lockless MPSC (Multiple Producer Single Consumer)
 * ring buffer library `ringbuf`.
 */
template<typename T>
class RingBuffer {
public:
    /**
     * Construct a new ring buffer.
     *
     * @param nProducers The total number of producers, each of which must be registered.
     * @param nSlots The number of slots (elements) in the ring buffer.
     */
    RingBuffer(unsigned nProducers, std::size_t nSlots) {
        std::size_t ringBufSize;
        ringbuf_get_sizes(nProducers, &ringBufSize, nullptr);
        ringbuf_ = {static_cast<ringbuf_t *>(malloc(ringBufSize)), free};

        // Add an extra byte, because for a buffer of n bytes, only n - 1 can
        // be produced at one time:
        // https://github.com/rmind/ringbuf/blob/master/src/t_ringbuf.c#L27
        const auto databufSize = (nSlots * sizeof(T)) + 1;
        databuf_ = std::shared_ptr<std::uint8_t>(new std::uint8_t[databufSize],
                                                 std::default_delete<std::uint8_t[]>());
        ringbuf_setup(ringbuf_.get(), nProducers, databufSize);

        nProducers_ = nProducers;
        std::atomic_init(&nRegisteredProducers_, static_cast<unsigned>(0));
        std::atomic_init(&nDrops_, static_cast<std::uint32_t>(0));
    }

    RingBuffer(const RingBuffer &) = delete;
    RingBuffer &operator=(const RingBuffer &) = delete;

    /**
     * Generates values that are written to the ring buffer.
     */
    class Producer {
    public:
        Producer(std::shared_ptr<ringbuf_t> ringbuf,
                 std::shared_ptr<std::uint8_t> databuf,
                 ringbuf_worker_t *worker) :
            ringbuf_(std::move(ringbuf)),
            databuf_(std::move(databuf)), worker_(worker) { }

        Producer(const Producer &other) = delete;

        ~Producer() {
            ringbuf_unregister(ringbuf_.get(), worker_);
        }

        /**
         * Writes data to the ring buffer.
         *
         * @param count The number of elements to produce.
         * @param producerFunc Function called with a pointer to a buffer to write `count`
         * elements into.
         * @returns Whether the data was produced successfully -- this may return `false`
         * if there is no space available to acquire in the ring buffer. The client can
         * choose to retry this call at a later point.
         */
        bool produce(std::size_t count,
                     std::function<void(T *data, std::size_t count)> producerFunc) {
            const auto offset = ringbuf_acquire(ringbuf_.get(), worker_, sizeof(T) * count);
            if (offset < 0) {
                return false;
            }
            producerFunc(reinterpret_cast<T *>(databuf_.get() + offset), count);
            ringbuf_produce(ringbuf_.get(), worker_);
            return true;
        }

    private:
        std::shared_ptr<ringbuf_t> ringbuf_;
        std::shared_ptr<std::uint8_t> databuf_;
        ringbuf_worker_t *worker_;
    };

    /**
     * Registers a producer that can write to the ring buffer.
     *
     * @return std::unique_ptr<Producer> A unique pointer to a `Producer` that
     * can write data to the ring buffer.
     */
    std::unique_ptr<Producer> registerProducer() {
        assert(nRegisteredProducers_ < nProducers_);
        const auto producerID = nRegisteredProducers_.fetch_add(1, std::memory_order_relaxed);
        const auto worker = ringbuf_register(ringbuf_.get(), producerID);
        if (worker == nullptr) {
            SPECTO_LOG_ERROR("Failed to register producer");
            return nullptr;
        }
        return std::make_unique<Producer>(ringbuf_, databuf_, worker);
    }

    /**
     * Consumes available data from the ring buffer. This function is only
     * safe to call from a single thread.
     *
     * @param consumerFunc If data is available, this function is called with
     * a pointer to the buffer and the number of elements to be read. The function
     * should return the actual number of elements read.
     */
    void consume(std::function<size_t(const T *data, std::size_t count)> consumerFunc) noexcept {
        std::size_t offset;
        const auto len = ringbuf_consume(ringbuf_.get(), &offset);
        if (len != 0) {
            const auto consumedCount =
              consumerFunc(reinterpret_cast<const T *>(databuf_.get() + offset), len / sizeof(T));
            ringbuf_release(ringbuf_.get(), consumedCount * sizeof(T));
        }
    }

    /**
     * Clears all available data from the ring buffer. This function is only
     * safe to call from a single thread.
     */
    void clear() noexcept {
        std::size_t offset;
        const auto len = ringbuf_consume(ringbuf_.get(), &offset);
        if (len != 0) {
            ringbuf_release(ringbuf_.get(), len);
        }
    }

    /**
     * Increment a counter that records the number of times data was dropped due to
     * an inability to acquire space in the ring buffer.
     * @note This is safe to call on any thread.
     */
    void incrementDropCounter() noexcept {
        nDrops_.fetch_add(1);
    }

    /**
     * Reset the value of the drop counter back to 0.
     * @note This is safe to call on any thread.
     */
    void resetDropCounter() noexcept {
        nDrops_.store(0);
    }

    /**
     * Returns the current value of the drop counter.
     * @note This is safe to call on any thread.
     */
    std::uint32_t getDropCounter() noexcept {
        return nDrops_.load();
    }

private:
    std::shared_ptr<ringbuf_t> ringbuf_;
    std::shared_ptr<std::uint8_t> databuf_;
    unsigned nProducers_;
    std::atomic<unsigned> nRegisteredProducers_;
    std::atomic<std::uint32_t> nDrops_;
};

} // namespace specto
