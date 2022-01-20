// Copyright (c) Specto Inc. All rights reserved.

#include "TraceConsumerMultiProxy.h"

namespace specto {

void TraceConsumerMultiProxy::addConsumer(std::shared_ptr<TraceConsumer> consumer) {
    if (consumer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(consumersLock_);
    consumers_.push_back(std::move(consumer));
}

void TraceConsumerMultiProxy::removeConsumer(std::shared_ptr<TraceConsumer> consumer) {
    if (consumer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(consumersLock_);
    consumers_.erase(std::remove_if(
      consumers_.begin(), consumers_.end(), [&](const auto &ptr) { return ptr == consumer; }));
}

void TraceConsumerMultiProxy::start(TraceID id) {
    forEachConsumer([&id](const auto &consumer) { consumer->start(id); });
}

void TraceConsumerMultiProxy::end(bool successful) {
    forEachConsumer([successful](const auto &consumer) { consumer->end(successful); });
}

void TraceConsumerMultiProxy::receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
    forEachConsumer([=](const auto &consumer) { consumer->receiveEntryBuffer(buf, size); });
}

TraceConsumerMultiProxy::TraceConsumerMultiProxy() = default;

void TraceConsumerMultiProxy::forEachConsumer(
  const std::function<void(const std::shared_ptr<TraceConsumer> &)> &f) const {
    decltype(consumers_) copiedConsumers;
    {
        std::lock_guard<std::mutex> l(consumersLock_);
        copiedConsumers = consumers_;
    }
    for (const auto &consumerPtr : copiedConsumers) {
        f(consumerPtr);
    }
}

} // namespace specto
