// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/ringbuffer/src/RingBuffer.h"

using namespace specto;

TEST(RingBufferTest, TestProduceConsumeSingle) {
    std::size_t capacity = 10;
    RingBuffer<int> ringbuffer {1, capacity};
    const auto producer = ringbuffer.registerProducer();
    for (decltype(capacity) i = 0; i < capacity; i++) {
        producer->produce(1,
                          [&](auto data, __unused auto count) { data[0] = static_cast<int>(i); });
    }
    ringbuffer.consume([&](auto data, auto count) {
        EXPECT_EQ(count, capacity);
        for (decltype(capacity) i = 0; i < capacity; i++) {
            EXPECT_EQ(data[i], i);
        }
        return count;
    });
}

TEST(RingBufferTest, TestProduceConsumeChunk) {
    std::size_t capacity = 10;
    RingBuffer<int> ringbuffer {1, capacity};
    const auto producer = ringbuffer.registerProducer();
    producer->produce(capacity, [&](auto data, __unused auto count) {
        for (decltype(capacity) i = 0; i < capacity; i++) {
            data[i] = static_cast<int>(i);
        }
    });
    ringbuffer.consume([&](auto data, auto count) {
        EXPECT_EQ(count, capacity);
        for (decltype(capacity) i = 0; i < capacity; i++) {
            EXPECT_EQ(data[i], i);
        }
        return count;
    });
}

TEST(RingBufferTest, TestClear) {
    std::size_t capacity = 10;
    RingBuffer<int> ringbuffer {1, capacity};
    const auto producer = ringbuffer.registerProducer();
    producer->produce(capacity, [&](auto data, __unused auto count) {
        for (decltype(capacity) i = 0; i < capacity; i++) {
            data[i] = static_cast<int>(i);
        }
    });
    ringbuffer.clear();
    ringbuffer.consume([&](__unused auto data, auto count) {
        EXPECT_EQ(count, 0);
        return count;
    });
}

TEST(RingBufferTest, TestEarlyWrapAround) {
    RingBuffer<int> ringbuffer {1, 10 /* 10 slots */};
    const auto producer = ringbuffer.registerProducer();

    // Produce as much data as possible given the capacity, in chunks of 2.
    // There's a difference between calling producer->produce(1, ...) twice
    // and producer->produce(2, ...) once: they're producing the same volume
    // of data, but the ring buffer will treat the latter case as a contiguous
    // chunk that must always be accessed as one "message".
    //
    // From the `ringbuf` docs:
    //
    // > The consumer will return a contiguous block of ranges produced i.e. the
    // > ringbuf_consume call will not return partial ranges. If you think of produced
    // > range as a message, then consumer will return a block of messages, always
    // > ending at the message boundary. Such behaviour allows us to use this ring
    // > buffer implementation as a message queue.
    for (int i = 0; i < 5; i++) {
        EXPECT_TRUE(producer->produce(2, [](auto data, __unused auto count) {
            data[0] = 0;
            data[1] = 0;
        }));
    }

    // Consume 4 entries from the head of the buffer -- this is equivalent to
    // 2 "messages" worth of data, since it was originally produced above in
    // chunks of 2.
    ringbuffer.consume([](__unused auto data, auto count) {
        EXPECT_GE(count, 4);
        return 4;
    });

    // Attempt to produce a chunk of 3 entries, which will not fit at the end of the buffer,
    // but an early wrap-around can be performed to insert it at the head.
    EXPECT_TRUE(producer->produce(3, [&](auto data, auto count) {
        for (decltype(count) i = 0; i < count; i++) {
            data[i] = static_cast<int>(i + 1);
        }
    }));

    // 10 entries originally produced, 4 were consumed, so there are 6 contiguous entries
    // left to read here.
    ringbuffer.consume([](auto data, auto count) {
        EXPECT_EQ(count, 6);
        for (int i = 0; i < 6; i++) {
            EXPECT_EQ(data[i], 0);
        }
        return count;
    });

    // The data produced the second time is in a separate chunk, so it will be consumed
    // separately -- 3 entries were produced.
    ringbuffer.consume([](auto data, auto count) {
        EXPECT_EQ(count, 3);
        for (int i = 0; i < 3; i++) {
            EXPECT_EQ(data[i], i + 1);
        }
        return count;
    });
}

TEST(RingBufferTest, TestDoesNotWrapAroundWhenContinguousRangeNotAvailable) {
    RingBuffer<int> ringbuffer {1, 10 /* 10 slots */};
    const auto producer = ringbuffer.registerProducer();

    // Produce enough data to fill the buffer.
    EXPECT_TRUE(producer->produce(10, [](__unused auto data, __unused auto count) {}));

    // Attempt to write a chunk of data that is too large to fit in a contiguous range
    // at both the head and tail of the buffer, verify that it fails.
    EXPECT_FALSE(producer->produce(1, [](__unused auto data, __unused auto count) {}));
}

TEST(RingBufferTest, TestIncrementGetDropCounter) {
    RingBuffer<int> ringbuffer {1, 10 /* 10 slots */};

    EXPECT_EQ(ringbuffer.getDropCounter(), 0);
    ringbuffer.incrementDropCounter();
    EXPECT_EQ(ringbuffer.getDropCounter(), 1);
}

TEST(RingBufferTest, TestResetDropCounter) {
    RingBuffer<int> ringbuffer {1, 10 /* 10 slots */};

    ringbuffer.incrementDropCounter();
    EXPECT_EQ(ringbuffer.getDropCounter(), 1);
    ringbuffer.resetDropCounter();
    EXPECT_EQ(ringbuffer.getDropCounter(), 0);
}
