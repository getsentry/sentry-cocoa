// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/darwin/backtrace/src/Backtrace.h"
#include "cpp/darwin/backtrace/src/ThreadMetadataCache.h"
#include "cpp/darwin/backtrace/testutils/Symbolicate.h"
#include "cpp/darwin/thread/src/ThreadHandle.h"
#include "cpp/portability/src/Compiler.h"
#include "cpp/util/src/ArraySize.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <cmath>
#include <iostream>
#include <pthread.h>
#include <thread>

using namespace specto::darwin;
using namespace specto::test;

// Avoid name mangling
extern "C" {
NOT_TAIL_CALLED NEVER_INLINE std::size_t
  c(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip) {
    auto current = ThreadHandle::current();
    return backtrace(
      *current, *current, addresses, current->stackBounds(), reachedEndOfStackPtr, maxDepth, skip);
}

NOT_TAIL_CALLED NEVER_INLINE std::size_t
  b(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip) {
    return c(addresses, reachedEndOfStackPtr, maxDepth, skip);
}

NOT_TAIL_CALLED NEVER_INLINE std::size_t
  a(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip) {
    return b(addresses, reachedEndOfStackPtr, maxDepth, skip);
}

[[noreturn]] NOT_TAIL_CALLED NEVER_INLINE void cancelLoop() {
    while (true) {
        pthread_testcancel();
    }
}

NOT_TAIL_CALLED NEVER_INLINE void bc_c() {
    cancelLoop();
}

NOT_TAIL_CALLED NEVER_INLINE void bc_e() {
    bc_c();
}

NOT_TAIL_CALLED NEVER_INLINE void bc_d() {
    bc_e();
}

NOT_TAIL_CALLED NEVER_INLINE void bc_b() {
    bc_c();
}

NOT_TAIL_CALLED NEVER_INLINE void bc_a() {
    bc_b();
}
}

namespace {
int indexOfSymbol(const std::uintptr_t *addresses, std::size_t depth, const char *symbol) {
    int index = -1;
    for (decltype(depth) i = 0; i < depth; i++) {
        const auto name = symbolicate(addresses[i]);
        std::cout << name << "\n";
        if (index == -1 && name == symbol) {
            index = i;
        }
    }
    return index;
}

void *threadEntry(__unused void *ptr) {
    if (pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, nullptr) != 0) {
        return nullptr;
    }
    if (pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, nullptr) != 0) {
        return nullptr;
    }
    const auto fn = (void (*)(void))(ptr);
    fn();
    return nullptr;
}
} // namespace

TEST(BacktraceTest, TestBacktrace) {
    std::uintptr_t addresses[128];
    std::memset(addresses, 0, specto::util::countof(addresses));
    bool reachedEndOfStack = false;
    EXPECT_GE(a(addresses, &reachedEndOfStack, specto::util::countof(addresses), 0), 3);
    EXPECT_TRUE(reachedEndOfStack);

    const auto index = indexOfSymbol(addresses, specto::util::countof(addresses), "c");
    EXPECT_NE(index, -1);
    if (index != -1) {
        EXPECT_EQ(symbolicate(addresses[index + 1]), "b");
        EXPECT_EQ(symbolicate(addresses[index + 2]), "a");
    }
}

TEST(BacktraceTest, TestBacktraceRespectsSkip) {
    std::uintptr_t addresses[128];
    std::memset(addresses, 0, specto::util::countof(addresses));
    bool reachedEndOfStack = false;
    EXPECT_GE(a(addresses, &reachedEndOfStack, specto::util::countof(addresses), 2), 3);
    EXPECT_TRUE(reachedEndOfStack);

    const auto indexC = indexOfSymbol(addresses, specto::util::countof(addresses), "c");
    EXPECT_EQ(indexC, -1);

    const auto indexB = indexOfSymbol(addresses, specto::util::countof(addresses), "b");
    EXPECT_NE(indexB, -1);
    if (indexB != -1) {
        EXPECT_EQ(symbolicate(addresses[indexB + 1]), "a");
    }
}

TEST(BacktraceTest, TestBacktraceRespectsMaxDepth) {
    std::uintptr_t addresses[2];
    std::memset(addresses, 0, specto::util::countof(addresses));
    addresses[1] = 0x8BADF00D;
    bool reachedEndOfStack = false;
    EXPECT_EQ(a(addresses, &reachedEndOfStack, 1, 0), 1);
    EXPECT_FALSE(reachedEndOfStack);
    EXPECT_EQ(addresses[1], 0x8BADF00D);
}

TEST(BacktraceCollectorTest, TestCollectsMultiThreadBacktrace) {
    pthread_t thread1, thread2;
    EXPECT_EQ(pthread_create(&thread1, nullptr, threadEntry, reinterpret_cast<void *>(bc_a)), 0);
    EXPECT_EQ(pthread_create(&thread2, nullptr, threadEntry, reinterpret_cast<void *>(bc_d)), 0);

    const auto cache = std::make_shared<ThreadMetadataCache>();
    bool foundThread1 = false, foundThread2 = false;
    // Try up to 3 times.
    for (int i = 0; i < 3; i++) {
        enumerateBacktracesForAllThreads(
          [&](auto entry) {
              const auto thread = entry->tid();
              const auto trace = entry->backtrace();
              if (thread == pthread_mach_thread_np(thread1)) {
                  const auto start =
                    indexOfSymbol(reinterpret_cast<const uintptr_t *>(trace.addresses().data()),
                                  trace.addresses_size(),
                                  "bc_c");
                  if (start != -1 && trace.addresses_size() >= 3) {
                      foundThread1 = true;
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start)), "bc_c");
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start + 1)), "bc_b");
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start + 2)), "bc_a");
                  }
              } else if (thread == pthread_mach_thread_np(thread2)) {
                  const auto start =
                    indexOfSymbol(reinterpret_cast<const uintptr_t *>(trace.addresses().data()),
                                  trace.addresses_size(),
                                  "bc_c");
                  if (start != -1 && trace.addresses_size() >= 3) {
                      foundThread2 = true;
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start)), "bc_c");
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start + 1)), "bc_e");
                      EXPECT_EQ(symbolicate(trace.addresses().Get(start + 2)), "bc_d");
                  }
              }
          },
          cache,
          true /* measureCost */);
        if (foundThread1 && foundThread2) {
            break;
        }
        std::this_thread::sleep_for(
          std::chrono::milliseconds(static_cast<long long>(std::pow(2, i + 1)) * 1000));
    }

    EXPECT_EQ(pthread_cancel(thread1), 0);
    EXPECT_EQ(pthread_join(thread1, nullptr), 0);
    EXPECT_EQ(pthread_cancel(thread2), 0);
    EXPECT_EQ(pthread_join(thread2, nullptr), 0);

    EXPECT_TRUE(foundThread1);
    EXPECT_TRUE(foundThread2);
}
