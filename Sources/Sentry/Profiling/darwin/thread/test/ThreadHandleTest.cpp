// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/darwin/thread/src/ThreadHandle.h"

#include <atomic>
#include <csignal>
#include <mach/mach.h>
#include <pthread.h>

using namespace specto::darwin;

namespace {
mach_port_t currentMachThread() {
    const auto port = mach_thread_self();
    mach_port_deallocate(mach_task_self(), port);
    return port;
}

void *threadSpin(__unused void *ptr) {
    if (pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, nullptr) != 0) {
        return nullptr;
    }
    if (pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, nullptr) != 0) {
        return nullptr;
    }
    while (true) {
        pthread_testcancel();
    }
    return nullptr;
}

void *threadGetName(void *namePtr) {
    const auto name = static_cast<const char *>(namePtr);
    pthread_setname_np(name);
    if (ThreadHandle::current()->name() == std::string(name)) {
        pthread_exit(reinterpret_cast<void *>(1));
    } else {
        pthread_exit(reinterpret_cast<void *>(0));
    }
}

} // namespace

TEST(ThreadHandleTest, TestGetNativeHandle) {
    ThreadHandle handle {currentMachThread()};
    EXPECT_EQ(handle.nativeHandle(), currentMachThread());
}

TEST(ThreadHandleTest, TestCurrent) {
    EXPECT_EQ(ThreadHandle::current()->nativeHandle(), currentMachThread());
}

TEST(ThreadHandleTest, TestAll) {
    pthread_t thread1, thread2;
    EXPECT_EQ(pthread_create(&thread1, nullptr, threadSpin, nullptr), 0);
    EXPECT_EQ(pthread_create(&thread2, nullptr, threadSpin, nullptr), 0);

    bool foundThread1 = false, foundThread2 = false, foundCurrentThread = false;
    for (const auto &thread : ThreadHandle::all()) {
        const auto pt = pthread_from_mach_thread_np(thread->nativeHandle());
        if (pthread_equal(pt, thread1)) {
            foundThread1 = true;
        } else if (pthread_equal(pt, thread2)) {
            foundThread2 = true;
        } else if (pthread_equal(pt, pthread_self())) {
            foundCurrentThread = true;
        }
        if (foundThread1 && foundThread2 && foundCurrentThread) {
            break;
        }
    }
    EXPECT_EQ(pthread_cancel(thread1), 0);
    EXPECT_EQ(pthread_join(thread1, nullptr), 0);

    EXPECT_EQ(pthread_cancel(thread2), 0);
    EXPECT_EQ(pthread_join(thread2, nullptr), 0);

    EXPECT_TRUE(foundThread1);
    EXPECT_TRUE(foundThread2);
    EXPECT_TRUE(foundCurrentThread);
}

TEST(ThreadHandleTest, TestAllExcludingCurrent) {
    pthread_t thread1, thread2;
    EXPECT_EQ(pthread_create(&thread1, nullptr, threadSpin, nullptr), 0);
    EXPECT_EQ(pthread_create(&thread2, nullptr, threadSpin, nullptr), 0);

    bool foundThread1 = false, foundThread2 = false, foundCurrentThread = false;
    const auto pair = ThreadHandle::allExcludingCurrent();
    EXPECT_EQ(pair.second->nativeHandle(), currentMachThread());
    for (const auto &thread : pair.first) {
        const auto pt = pthread_from_mach_thread_np(thread->nativeHandle());
        if (pthread_equal(pt, thread1)) {
            foundThread1 = true;
        } else if (pthread_equal(pt, thread2)) {
            foundThread2 = true;
        } else if (pthread_equal(pt, pthread_self())) {
            foundCurrentThread = true;
        }
    }
    EXPECT_EQ(pthread_cancel(thread1), 0);
    EXPECT_EQ(pthread_join(thread1, nullptr), 0);

    EXPECT_EQ(pthread_cancel(thread2), 0);
    EXPECT_EQ(pthread_join(thread2, nullptr), 0);

    EXPECT_TRUE(foundThread1);
    EXPECT_TRUE(foundThread2);
    EXPECT_FALSE(foundCurrentThread);
}

TEST(ThreadHandleTest, TestName) {
    pthread_t thread;
    char name[] = "test-thread";

    EXPECT_EQ(pthread_create(&thread, nullptr, threadGetName, static_cast<void *>(name)), 0);
    void *rv = nullptr;
    EXPECT_EQ(pthread_join(thread, &rv), 0);
    EXPECT_EQ(rv, reinterpret_cast<void *>(1));
}

TEST(ThreadHandleTest, TestPriority) {
    pthread_attr_t attr;
    EXPECT_EQ(pthread_attr_init(&attr), 0);
    const int priority = 50;
    struct sched_param param = {.sched_priority = priority};
    EXPECT_EQ(pthread_attr_setschedparam(&attr, &param), 0);

    pthread_t thread;
    EXPECT_EQ(pthread_create(&thread, &attr, threadSpin, nullptr), 0);
    EXPECT_EQ(pthread_attr_destroy(&attr), 0);

    EXPECT_EQ(ThreadHandle(pthread_mach_thread_np(thread)).priority(), priority);

    EXPECT_EQ(pthread_cancel(thread), 0);
    EXPECT_EQ(pthread_join(thread, nullptr), 0);
}

TEST(ThreadHandleTest, TestGetStackBounds) {
    const auto bounds = ThreadHandle::current()->stackBounds();
    EXPECT_GT(bounds.start, 0);
    EXPECT_GT(bounds.end, 0);
    EXPECT_GT(bounds.start - bounds.end, 0);
    EXPECT_TRUE(bounds.contains(reinterpret_cast<std::uintptr_t>(&bounds)));

    int *heapInt = new int;
    EXPECT_FALSE(bounds.contains(reinterpret_cast<std::uintptr_t>(heapInt)));
    delete heapInt;
}

// TEST(ThreadHandleTest, TestQoS) {
//     pthread_attr_t attr;
//     EXPECT_EQ(pthread_attr_init(&attr), 0);
//     const auto qosClass = QOS_CLASS_UTILITY;
//     const int relativePriority = 5;
//     EXPECT_EQ(pthread_attr_set_qos_class_np(&attr, qosClass, relativePriority), 0);

//     // This is broken right now, I suspect it has something to do with this:
//     // https://github.com/apple/darwin-libpthread/blob/master/tests/pthread_get_qos_class_np.c
//     qos_class_t requestedQoSClass;
//     int requestedRelativePriority;
//     EXPECT_EQ(pthread_attr_get_qos_class_np(&attr, &requestedQoSClass,
//     &requestedRelativePriority),
//               0);
//     EXPECT_EQ(requestedQoSClass, qosClass);
//     EXPECT_EQ(requestedRelativePriority, relativePriority);

//     pthread_t thread;
//     EXPECT_EQ(pthread_create(&thread, &attr, threadSpin, nullptr), 0);
//     EXPECT_EQ(pthread_attr_destroy(&attr), 0);

//     const auto qos = ThreadHandle(pthread_mach_thread_np(thread)).qos();
//     EXPECT_EQ(qos.qosClass, qosClass);
//     EXPECT_EQ(qos.relativePriority, relativePriority);

//     EXPECT_EQ(pthread_cancel(thread), 0);
//     EXPECT_EQ(pthread_join(thread, nullptr), 0);
// }
