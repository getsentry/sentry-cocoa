// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/trace/src/TraceEventSubject.h"
#include "cpp/trace/testutils/TestTraceEventObserver.h"

#include <memory>

using namespace specto;
using namespace specto::test;

namespace {

TraceID kTestTraceID;

} // namespace

TEST(TraceEventSubjectTest, TestAddRemoveObserver) {
    TraceEventSubject subject;
    auto observer = std::make_shared<TestTraceEventObserver>();
    subject.addObserver(observer);

    subject.traceStarted(kTestTraceID);
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_EQ(observer->lastTraceID, kTestTraceID);

    subject.removeObserver(observer);
    subject.traceEnded(kTestTraceID);
    EXPECT_EQ(observer->calledTraceEnded, false);
}

TEST(TraceEventSubjectTest, TestCallsTraceStarted) {
    TraceEventSubject subject;
    auto observer = std::make_shared<TestTraceEventObserver>();
    subject.addObserver(observer);

    subject.traceStarted(kTestTraceID);
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_EQ(observer->lastTraceID, kTestTraceID);
}

TEST(TraceEventSubjectTest, TestCallsTraceEnded) {
    TraceEventSubject subject;
    auto observer = std::make_shared<TestTraceEventObserver>();
    subject.addObserver(observer);

    subject.traceEnded(kTestTraceID);
    EXPECT_TRUE(observer->calledTraceEnded);
    EXPECT_EQ(observer->lastTraceID, kTestTraceID);
}

TEST(TraceEventSubjectTest, TestCallsTraceFailed) {
    TraceEventSubject subject;
    auto observer = std::make_shared<TestTraceEventObserver>();
    subject.addObserver(observer);

    proto::Error error;
    error.set_code(proto::Error_Code_UNDEFINED);
    error.set_description("Undefined");

    subject.traceFailed(kTestTraceID, error);
    EXPECT_TRUE(observer->calledTraceFailed);
    EXPECT_EQ(observer->lastTraceID, kTestTraceID);
    EXPECT_EQ(observer->lastError->code(), error.code());
    EXPECT_EQ(observer->lastError->description(), error.description());
}
