#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <XCTest/XCTest.h>

#    import "SentryThreadHandle.h"

#    import <atomic>
#    import <csignal>
#    import <mach/mach.h>
#    import <pthread.h>

using namespace sentry::profiling;

namespace {
mach_port_t
currentMachThread()
{
    const auto port = mach_thread_self();
    mach_port_deallocate(mach_task_self(), port);
    return port;
}

void *
threadSpin(__unused void *ptr)
{
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

void *
threadGetName(void *namePtr)
{
    const auto name = static_cast<const char *>(namePtr);
    pthread_setname_np(name);
    if (ThreadHandle::current()->name() == std::string(name)) {
        pthread_exit(reinterpret_cast<void *>(1));
    } else {
        pthread_exit(reinterpret_cast<void *>(0));
    }
}
} // namespace

@interface SentryThreadHandleTests : XCTestCase
@end

@implementation SentryThreadHandleTests

- (void)testGetNativeHandle
{
    ThreadHandle handle { currentMachThread() };
    XCTAssertEqual(handle.nativeHandle(), currentMachThread());
}

- (void)testCurrent
{
    XCTAssertEqual(ThreadHandle::current()->nativeHandle(), currentMachThread());
}

- (void)testAll
{
    pthread_t thread1, thread2;
    XCTAssertEqual(pthread_create(&thread1, nullptr, threadSpin, nullptr), 0);
    XCTAssertEqual(pthread_create(&thread2, nullptr, threadSpin, nullptr), 0);

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
    XCTAssertEqual(pthread_cancel(thread1), 0);
    XCTAssertEqual(pthread_join(thread1, nullptr), 0);

    XCTAssertEqual(pthread_cancel(thread2), 0);
    XCTAssertEqual(pthread_join(thread2, nullptr), 0);

    XCTAssertTrue(foundThread1);
    XCTAssertTrue(foundThread2);
    XCTAssertTrue(foundCurrentThread);
}

- (void)testAllExcludingCurrent
{
    pthread_t thread1, thread2;
    XCTAssertEqual(pthread_create(&thread1, nullptr, threadSpin, nullptr), 0);
    XCTAssertEqual(pthread_create(&thread2, nullptr, threadSpin, nullptr), 0);

    bool foundThread1 = false, foundThread2 = false, foundCurrentThread = false;
    const auto pair = ThreadHandle::allExcludingCurrent();
    XCTAssertEqual(pair.second->nativeHandle(), currentMachThread());
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
    XCTAssertEqual(pthread_cancel(thread1), 0);
    XCTAssertEqual(pthread_join(thread1, nullptr), 0);

    XCTAssertEqual(pthread_cancel(thread2), 0);
    XCTAssertEqual(pthread_join(thread2, nullptr), 0);

    XCTAssertTrue(foundThread1);
    XCTAssertTrue(foundThread2);
    XCTAssertFalse(foundCurrentThread);
}

- (void)testName
{
    pthread_t thread;
    char name[] = "test-thread";

    XCTAssertEqual(pthread_create(&thread, nullptr, threadGetName, static_cast<void *>(name)), 0);
    void *rv = nullptr;
    XCTAssertEqual(pthread_join(thread, &rv), 0);
    XCTAssertEqual(rv, reinterpret_cast<void *>(1));
}

- (void)testPriority
{
    pthread_attr_t attr;
    XCTAssertEqual(pthread_attr_init(&attr), 0);
    const int priority = 50;
    struct sched_param param = { .sched_priority = priority };
    XCTAssertEqual(pthread_attr_setschedparam(&attr, &param), 0);

    pthread_t thread;
    XCTAssertEqual(pthread_create(&thread, &attr, threadSpin, nullptr), 0);
    XCTAssertEqual(pthread_attr_destroy(&attr), 0);

    XCTAssertEqual(ThreadHandle(pthread_mach_thread_np(thread)).priority(), priority);

    XCTAssertEqual(pthread_cancel(thread), 0);
    XCTAssertEqual(pthread_join(thread, nullptr), 0);
}

- (void)testGetStackBounds
{
    const auto bounds = ThreadHandle::current()->stackBounds();
    XCTAssertGreaterThan(bounds.start, static_cast<unsigned long>(0));
    XCTAssertGreaterThan(bounds.end, static_cast<unsigned long>(0));
    XCTAssertGreaterThan(bounds.start - bounds.end, static_cast<unsigned long>(0));
    XCTAssertTrue(bounds.contains(reinterpret_cast<std::uintptr_t>(&bounds)));

    int *heapInt = new int;
    XCTAssertFalse(bounds.contains(reinterpret_cast<std::uintptr_t>(heapInt)));
    delete heapInt;
}

@end

#endif
