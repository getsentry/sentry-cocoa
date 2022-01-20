// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/tracelogger/src/PacketStreamID.h"

using namespace specto;

TEST(PacketStreamIDTest, TestStreamIDMonotonicallyIncreasing) {
    const auto id1 = PacketStreamID::getNext();
    const auto id2 = PacketStreamID::getNext();
    EXPECT_GT(id2, id1);
}
