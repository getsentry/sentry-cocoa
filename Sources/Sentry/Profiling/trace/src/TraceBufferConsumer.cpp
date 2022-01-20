// Copyright (c) Specto Inc. All rights reserved.

#include "TraceBufferConsumer.h"

#include "TraceConsumer.h"
#include "cpp/exception/src/Exception.h"
#include "cpp/tracelogger/src/EntryParser.h"
#include "cpp/util/src/ScopeGuard.h"

#include <cassert>
#include <utility>

namespace specto {

void TraceBufferConsumer::notify(std::shared_ptr<EntryParser> entryParser,
                                 std::shared_ptr<TraceConsumer> traceConsumer,
                                 std::function<void(void)> completionHandler) {
    assert(entryParser != nullptr);
    assert(traceConsumer != nullptr);
    {
        std::lock_guard<std::mutex> l(mutex_);
        queue_.push(
          {std::move(entryParser), std::move(traceConsumer), std::move(completionHandler)});
    }
    condvar_.notify_all();
}

void TraceBufferConsumer::startLoop() {
    std::atomic_store_explicit(&isConsuming_, true, std::memory_order_release);
    while (!SPECTO_IS_CPP_EXCEPTION_KILLSWITCH_SET()) {
        Notification notification;
        {
            std::unique_lock<std::mutex> lock(mutex_);
            condvar_.wait(lock, [this, &notification] {
                if (this->queue_.empty()) {
                    return false;
                }
                notification = this->queue_.front();
                this->queue_.pop();
                return true;
            });
        }

        SPECTO_DEFER({
            if (notification.completionHandler != nullptr) {
                notification.completionHandler();
            }
        });

        if (notification.entryParser == nullptr || notification.traceConsumer == nullptr) {
            // Special values used to signal the end of the loop.
            std::atomic_store_explicit(&isConsuming_, false, std::memory_order_release);
            return;
        }
        notification.entryParser->parse([&notification](auto buf, auto size) {
            auto ptr = std::shared_ptr<char>(new char[size], std::default_delete<char[]>());
            std::memcpy(ptr.get(), buf, size);
            notification.traceConsumer->receiveEntryBuffer(std::move(ptr), size);
        });
    }
}

void TraceBufferConsumer::stopLoop(std::function<void(void)> completionHandler) {
    {
        std::lock_guard<std::mutex> l(mutex_);
        // Special values used to signal the end of the loop.
        queue_.push({nullptr, nullptr, std::move(completionHandler)});
    }
    condvar_.notify_all();
}

bool TraceBufferConsumer::isConsuming() const {
    return std::atomic_load_explicit(&isConsuming_, std::memory_order_acquire);
}

TraceBufferConsumer::TraceBufferConsumer() = default;

} // namespace specto
