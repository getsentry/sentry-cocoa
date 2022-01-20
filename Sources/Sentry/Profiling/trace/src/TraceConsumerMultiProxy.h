// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "TraceConsumer.h"

#include <functional>
#include <memory>
#include <mutex>
#include <vector>

namespace specto {
/** Proxy that forwards trace consumer events to multiple consumers. */
class TraceConsumerMultiProxy : public TraceConsumer {
public:
    /** Add a new consumer to be forwarded events. */
    void addConsumer(std::shared_ptr<TraceConsumer> consumer);
    /** Remove a previously registered consumer. */
    void removeConsumer(std::shared_ptr<TraceConsumer> consumer);

    /** Forwarded events. */
    void start(TraceID id) override;
    void end(bool successful) override;
    void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) override;

    TraceConsumerMultiProxy();
    TraceConsumerMultiProxy(const TraceConsumerMultiProxy &) = delete;
    TraceConsumerMultiProxy &operator=(const TraceConsumerMultiProxy &) = delete;

private:
    void
      forEachConsumer(const std::function<void(const std::shared_ptr<TraceConsumer> &)> &f) const;

    std::vector<std::shared_ptr<TraceConsumer>> consumers_;
    mutable std::mutex consumersLock_;
};
} // namespace specto
