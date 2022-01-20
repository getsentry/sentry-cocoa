// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/traceid/src/TraceID.h"

#include <algorithm>
#include <random>

using namespace specto;

TEST(TraceIDTest, TestTraceIDEquality) {
    TraceID id;
    EXPECT_EQ(id, id);
    EXPECT_NE(id, TraceID {});
}

TEST(TraceIDTest, TestTwoSequentialIDsAreDifferent) {
    EXPECT_NE(TraceID {}, TraceID {});
}

TEST(TraceIDTest, ExpectDefaultConstructedTraceIDNotEmpty) {
    TraceID traceID;
    EXPECT_FALSE(traceID.isEmpty());
    EXPECT_NE(traceID, TraceID::empty);
}

TEST(TraceIDTest, TestEmptySingletonTraceIDIsEmpty) {
    EXPECT_TRUE(TraceID::empty.isEmpty());
}

TEST(TraceIDTest, TestGeneratorDoesntOverflow) {
    bool useMax = true;
    thread_local std::vector<uint8_t> data(2);

    std::generate(data.begin(), data.end(), [&]() {
        if (useMax) {
            useMax = false;
            return UINT_MAX;
        } else {
            useMax = true;
            return 0U;
        }
    });

    std::vector<uint8_t> expected {255, 0};
    EXPECT_EQ(data, expected);
}

TEST(TraceIDTest, TestIsEmptyForUUIDStartingWithZero) {
    std::vector<uint8_t> urandomData(16);
    std::random_device rd;
    std::generate(urandomData.begin(), urandomData.end(), std::ref(rd));

    TraceID::UUID uuidBytes;
    std::copy(urandomData.begin(), urandomData.end(), uuidBytes);
    uuidBytes[0] = 0;
    TraceID traceID(uuidBytes);
    EXPECT_FALSE(traceID.isEmpty());
}

TEST(TraceIDTest, TestIsEmptyForUUIDEndingWithZero) {
    std::vector<uint8_t> urandomData(16);
    std::random_device rd;
    std::generate(urandomData.begin(), urandomData.end(), std::ref(rd));

    TraceID::UUID uuidBytes;
    std::copy(urandomData.begin(), urandomData.end(), uuidBytes);
    uuidBytes[sizeof(uuidBytes) - 1] = 0;
    TraceID traceID(uuidBytes);
    EXPECT_FALSE(traceID.isEmpty());
}

TEST(TraceIDTest, TestIsEmptyForUUIDWithAZeroInTheMiddle) {
    std::vector<uint8_t> urandomData(16);
    std::random_device rd;
    std::generate(urandomData.begin(), urandomData.end(), std::ref(rd));

    TraceID::UUID uuidBytes;
    std::copy(urandomData.begin(), urandomData.end(), uuidBytes);
    uuidBytes[8] = 0;
    TraceID traceID(uuidBytes);
    EXPECT_FALSE(traceID.isEmpty());
}

TEST(TraceIDTest, TestIsEmptyForAllZeroTraceID) {
    TraceID::UUID uuidBytes;
    std::memset(uuidBytes, 0, sizeof(uuidBytes));
    TraceID traceID(uuidBytes);
    EXPECT_TRUE(traceID.isEmpty());
}
