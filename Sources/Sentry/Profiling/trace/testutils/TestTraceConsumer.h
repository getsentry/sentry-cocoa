// Copyright (c) Specto Inc. All rights reserved.

#include "cpp/trace/src/TraceConsumer.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <mutex>

namespace specto {
namespace test {
class TestTraceConsumer : public TraceConsumer {
public:
    void start(TraceID id) override;
    void end(bool successful) override;
    void receiveEntryBuffer(std::shared_ptr<char>, std::size_t size) override;

    TestTraceConsumer();
    TestTraceConsumer(const TestTraceConsumer &) = delete;
    TestTraceConsumer &operator=(const TestTraceConsumer &) = delete;

    TraceID id() const;
    bool calledEnd() const;
    bool endSuccessful() const;
    std::vector<proto::Entry> entries() const;

private:
    mutable std::mutex mutex_;
    TraceID id_;
    bool calledEnd_ = false;
    bool endSuccessful_ = false;
    std::vector<proto::Entry> entries_;
};
} // namespace test
} // namespace specto
