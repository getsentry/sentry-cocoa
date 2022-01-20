// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/trace/src/TraceConsumerMultiProxy.h"
#include "cpp/trace/testutils/TestTraceConsumer.h"
#include "cpp/traceid/src/TraceID.h"
#include "cpp/tracelogger/src/TraceLogger.h"

#include <memory>

using namespace specto;
using namespace specto::test;

namespace {

TraceID kTestTraceID;

} // namespace

TEST(TraceConsumerMultiProxyTest, TestAddRemoveObserver) {
    TraceConsumerMultiProxy proxy;
    auto consumer = std::make_shared<TestTraceConsumer>();
    proxy.addConsumer(consumer);

    proxy.start(kTestTraceID);
    EXPECT_EQ(consumer->id(), kTestTraceID);

    proxy.removeConsumer(consumer);
    proxy.end(true);
    EXPECT_FALSE(consumer->calledEnd());
    EXPECT_FALSE(consumer->endSuccessful());
}

TEST(TraceConsumerMultiProxyTest, TestCallsTraceStarted) {
    TraceConsumerMultiProxy proxy;
    auto consumer = std::make_shared<TestTraceConsumer>();
    proxy.addConsumer(consumer);

    proxy.start(kTestTraceID);
    EXPECT_EQ(consumer->id(), kTestTraceID);
}

TEST(TraceConsumerMultiProxyTest, TestCallsTraceEnded) {
    TraceConsumerMultiProxy proxy;
    auto consumer = std::make_shared<TestTraceConsumer>();
    proxy.addConsumer(consumer);

    proxy.end(false);
    EXPECT_TRUE(consumer->calledEnd());
    EXPECT_FALSE(consumer->endSuccessful());
}

TEST(TraceConsumerMultiProxyTest, TestCallsReceiveEntry) {
    TraceConsumerMultiProxy proxy;
    auto consumer = std::make_shared<TestTraceConsumer>();
    proxy.addConsumer(consumer);

    auto entry = protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE);
    const auto size = entry.ByteSizeLong();
    std::shared_ptr<char> buf(new char[size], std::default_delete<char[]>());
    entry.SerializeToArray(buf.get(), size);
    proxy.receiveEntryBuffer(buf, size);

    EXPECT_EQ(consumer->entries().size(), 1);
    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_TRACE_FAILURE);
}
