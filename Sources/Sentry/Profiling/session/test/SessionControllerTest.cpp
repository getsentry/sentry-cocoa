// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/session/src/SessionController.h"
#include "cpp/trace/testutils/TestTraceConsumer.h"
#include "spectoproto/entry/entry_generated.pb.h"

using namespace specto;
using namespace specto::test;

TEST(SessionControllerTest, TestReturnsEmptySessionIDWhenThereIsNoSession) {
    SessionController controller {};
    EXPECT_EQ(controller.currentSessionID(), TraceID::empty);
}

TEST(SessionControllerTest, TestSessionIDIsSetAfterCallingStartSession) {
    SessionController controller {};
    controller.startSession(std::make_shared<TestTraceConsumer>());
    EXPECT_NE(controller.currentSessionID(), TraceID::empty);
}

TEST(SessionControllerTest, TestSessionIDIsEmptyAfterCallingEndSession) {
    SessionController controller {};
    controller.startSession(std::make_shared<TestTraceConsumer>());
    controller.endSession();
    EXPECT_EQ(controller.currentSessionID(), TraceID::empty);
}

TEST(SessionControllerTest, TestCallingStartSessionWithExistingSessionStartsNew) {
    SessionController controller {};
    controller.startSession(std::make_shared<TestTraceConsumer>());

    auto id = controller.currentSessionID();
    controller.startSession(std::make_shared<TestTraceConsumer>());

    EXPECT_NE(controller.currentSessionID(), id);
    EXPECT_NE(id, TraceID::empty);
}

TEST(SessionControllerTest, TestCallingStartSessionCallsConsumer) {
    SessionController controller {};
    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller.startSession(consumer);

    EXPECT_EQ(consumer->entries().size(), 1);
    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_SESSION_START);
    EXPECT_EQ(consumer->entries()[0].group_id(), controller.currentSessionID().uuid());
}

TEST(SessionControllerTest, TestCallingLogCallsConsumer) {
    SessionController controller {};
    const auto consumer = std::make_shared<TestTraceConsumer>();

    proto::Entry entry;
    entry.set_type(proto::Entry_Type_TRACE_START);

    controller.startSession(consumer);
    controller.log(entry);

    EXPECT_EQ(consumer->entries().size(), 2);
    EXPECT_EQ(consumer->entries()[1].type(), entry.type());
}

TEST(SessionControllerTest, TestCallingUnsafeLogBytesCallsConsumer) {
    SessionController controller {};
    const auto consumer = std::make_shared<TestTraceConsumer>();

    proto::Entry entry;
    entry.set_type(proto::Entry_Type_TRACE_START);
    const auto size = entry.ByteSizeLong();
    std::shared_ptr<char> buf(new char[size], std::default_delete<char[]>());
    entry.SerializeToArray(buf.get(), size);

    controller.startSession(consumer);
    controller.unsafeLogBytes(std::move(buf), size);

    EXPECT_EQ(consumer->entries().size(), 2);
    EXPECT_EQ(consumer->entries()[1].type(), entry.type());
}

TEST(SessionControllerTest, TestCallingEndSessionCallsConsumer) {
    SessionController controller {};
    const auto consumer = std::make_shared<TestTraceConsumer>();

    controller.startSession(consumer);
    const auto id = controller.currentSessionID();
    controller.endSession();

    EXPECT_TRUE(consumer->calledEnd());
    EXPECT_EQ(consumer->entries().size(), 2);
    EXPECT_EQ(consumer->entries()[1].type(), proto::Entry_Type_SESSION_END);
    EXPECT_EQ(consumer->entries()[1].group_id(), id.uuid());
}
