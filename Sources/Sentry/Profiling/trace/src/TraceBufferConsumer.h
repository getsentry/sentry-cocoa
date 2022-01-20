// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <utility>

namespace specto {
class EntryParser;
class TraceConsumer;

/**
 * Consumes trace entries from a buffer and passes the data to a trace consumer.
 */
class TraceBufferConsumer {
public:
    /**
     * Notify the consumer that new data is available to read from the buffer.
     *
     * @param entryParser Used to read and parse entries from the trace buffer.
     * @param traceConsumer The trace consumer to pass the entries parsed from the buffer to.
     * @param completionHandler Optional function called when the notification is processed
     * and data has been read.
     */
    void notify(std::shared_ptr<EntryParser> entryParser,
                std::shared_ptr<TraceConsumer> traceConsumer,
                std::function<void(void)> completionHandler = nullptr);

    /**
     * Start the loop to read data from the trace buffer. This function should be
     * called on a dedicated thread. The function will not return until `stopLoop`
     * has been called.
     */
    void startLoop();

    /**
     * Stop the read loop previously started by calling `startLoop`.
     *
     * @param completionHandler Optional function called once the loop has exited.
     */
    void stopLoop(std::function<void(void)> completionHandler = nullptr);

    /**
     * @return Whether the consumer is currently consuming data in a loop.
     */
    bool isConsuming() const;

    TraceBufferConsumer();
    TraceBufferConsumer(const TraceBufferConsumer &) = delete;
    TraceBufferConsumer &operator=(const TraceBufferConsumer &) = delete;

private:
    struct Notification {
        std::shared_ptr<EntryParser> entryParser;
        std::shared_ptr<TraceConsumer> traceConsumer;
        std::function<void(void)> completionHandler;
    };

    std::queue<Notification> queue_;
    std::mutex mutex_;
    std::condition_variable condvar_;
    std::atomic_bool isConsuming_ {false};
};
} // namespace specto
