// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/util/src/Pool.h"

using namespace specto::util;

TEST(PoolTest, TestConstructsWhenPoolIsEmpty) {
    int constructorCount = 0;
    auto pool = Pool<int *>(3, [&]() {
        constructorCount++;
        return new int;
    });

    pool.get();
    EXPECT_EQ(constructorCount, 1);
}

TEST(PoolTest, TestReturnsRecycledValueWhenAvailable) {
    int constructorCount = 0;
    auto pool = Pool<int *>(3, [&]() {
        constructorCount++;
        return new int;
    });
    const auto intPtr = new int;
    pool.recycle(intPtr);

    EXPECT_EQ(pool.get(), intPtr);
    EXPECT_EQ(constructorCount, 0);
}

TEST(PoolTest, TestRespectsLimit) {
    int constructorCount = 0;
    auto pool = Pool<int *>(1, [&]() {
        constructorCount++;
        return new int;
    });

    const auto intPtr1 = new int;
    const auto intPtr2 = new int;
    pool.recycle(intPtr1);
    pool.recycle(intPtr2);

    EXPECT_EQ(pool.get(), intPtr1);
    EXPECT_NE(pool.get(), intPtr2);
    EXPECT_EQ(constructorCount, 1);
}

TEST(PoolTest, TestCallsDeleter) {
    int deleterCount = 0;
    {
        auto pool = Pool<int *>(
          2,
          [&]() { return new int; },
          [&](auto ptr) {
              deleterCount++;
              delete ptr;
          });
        pool.recycle(new int);
        pool.recycle(new int);
    }
    EXPECT_EQ(deleterCount, 2);
}
