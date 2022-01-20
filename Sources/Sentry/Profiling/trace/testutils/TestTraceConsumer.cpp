// Copyright (c) Specto Inc. All rights reserved.

#include "TestTraceConsumer.h"

#include "spectoproto/entry/entry_generated.pb.h"

namespace specto::test {
void TestTraceConsumer::start(TraceID id) {
    std::lock_guard<std::mutex> l(mutex_);
    id_ = id;
}

void TestTraceConsumer::end(bool successful) {
    std::lock_guard<std::mutex> l(mutex_);
    calledEnd_ = true;
    endSuccessful_ = successful;
}

void TestTraceConsumer::receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
    std::lock_guard<std::mutex> l(mutex_);
    proto::Entry entry;
    entry.ParseFromArray(buf.get(), static_cast<int>(size));
    entries_.push_back(std::move(entry));
}

TestTraceConsumer::TestTraceConsumer() = default;

TraceID TestTraceConsumer::id() const {
    std::lock_guard<std::mutex> l(mutex_);
    return id_;
}

bool TestTraceConsumer::calledEnd() const {
    std::lock_guard<std::mutex> l(mutex_);
    return calledEnd_;
}

bool TestTraceConsumer::endSuccessful() const {
    std::lock_guard<std::mutex> l(mutex_);
    return endSuccessful_;
}

std::vector<proto::Entry> TestTraceConsumer::entries() const {
    std::lock_guard<std::mutex> l(mutex_);
    return entries_;
}

} // namespace specto::test
