// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/persistence/src/TraceFileEventSubject.h"
#include "cpp/persistence/testutils/TestTraceFileEventObserver.h"

using namespace specto;
using namespace specto::test;

TEST(TraceFileEventSubjectTest, TestAddRemoveObserver) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFileCompleted(filesystem::Path {}, filesystem::Path {});
    EXPECT_TRUE(observer->calledTraceFileCompleted);

    subject.removeObserver(observer);
    subject.traceFileUploadQueued(filesystem::Path {}, filesystem::Path {});
    EXPECT_FALSE(observer->calledTraceFileUploadQueued);
}

TEST(TraceFileEventSubjectTest, TestCallsTraceFileCompleted) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFileCompleted(filesystem::Path("foo"), filesystem::Path("bar"));
    EXPECT_TRUE(observer->calledTraceFileCompleted);
    EXPECT_EQ(observer->lastOldPath.string(), "foo");
    EXPECT_EQ(observer->lastNewPath.string(), "bar");
}

TEST(TraceFileEventSubjectTest, TestCallsTraceFileUploadQueued) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFileUploadQueued(filesystem::Path("foo"), filesystem::Path("bar"));
    EXPECT_TRUE(observer->calledTraceFileUploadQueued);
    EXPECT_EQ(observer->lastOldPath.string(), "foo");
    EXPECT_EQ(observer->lastNewPath.string(), "bar");
}

TEST(TraceFileEventSubjectTest, TestCallsTraceFileUploadCancelled) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFileUploadCancelled(filesystem::Path("foo"), filesystem::Path("bar"));
    EXPECT_TRUE(observer->calledTraceFileUploadCancelled);
    EXPECT_EQ(observer->lastOldPath.string(), "foo");
    EXPECT_EQ(observer->lastNewPath.string(), "bar");
}

TEST(TraceFileEventSubjectTest, TestCallsTraceFileUploadFinished) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFileUploadFinished(filesystem::Path("foo"));
    EXPECT_TRUE(observer->calledTraceFileUploadFinished);
    EXPECT_EQ(observer->lastOldPath.string(), "foo");
}

TEST(TraceFileEventSubjectTest, TestCallsTraceFilePruned) {
    TraceFileEventSubject subject;
    auto observer = std::make_shared<TestTraceFileEventObserver>();

    subject.addObserver(observer);

    subject.traceFilePruned(filesystem::Path("foo"));
    EXPECT_TRUE(observer->calledTraceFilePruned);
    EXPECT_EQ(observer->lastOldPath.string(), "foo");
}
