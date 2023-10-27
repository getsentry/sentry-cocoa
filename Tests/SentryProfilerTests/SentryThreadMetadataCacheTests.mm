#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <XCTest/XCTest.h>

#    import "SentryMachLogging.hpp"
#    import "SentryThreadMetadataCache.hpp"

#    import <pthread.h>
#    import <thread>

using namespace sentry::profiling;

@interface SentryThreadMetadataCacheTests : XCTestCase
@end

namespace {
void *
threadSpin(void *name)
{
    SENTRY_PROF_LOG_ERROR_RETURN(pthread_setname_np(reinterpret_cast<const char *>(name)));
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
} // namespace

@implementation SentryThreadMetadataCacheTests

- (void)testRetrievesThreadMetadata
{
    pthread_t thread;
    char name[] = "SentryThreadMetadataCacheTests";
    XCTAssertEqual(pthread_create(&thread, nullptr, threadSpin, reinterpret_cast<void *>(name)), 0);
    int policy;
    sched_param param;
    if (SENTRY_PROF_LOG_ERROR_RETURN(pthread_getschedparam(thread, &policy, &param)) == 0) {
        param.sched_priority = 50;
        SENTRY_PROF_LOG_ERROR_RETURN(pthread_setschedparam(thread, policy, &param));
    }

    // give the other thread a little time to spawn, otherwise its name comes back as an empty
    // string and the isSentryOwnedThreadName check will fail
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    const auto cache = std::make_shared<ThreadMetadataCache>();
    ThreadHandle handle(pthread_mach_thread_np(thread));
    const auto metadata = cache->metadataForThread(handle);
    XCTAssertTrue(metadata.name == handle.name());
    XCTAssertEqual(metadata.priority, handle.priority());
    XCTAssertEqual(metadata.threadID, handle.tid());

    XCTAssertEqual(pthread_cancel(thread), 0);
    XCTAssertEqual(pthread_join(thread, nullptr), 0);
}

- (void)testReturnsCachedThreadMetadata
{
    pthread_t thread;
    char name[] = "SentryThreadMetadataCacheTests";
    XCTAssertEqual(pthread_create(&thread, nullptr, threadSpin, reinterpret_cast<void *>(name)), 0);
    int policy;
    sched_param param;
    if (SENTRY_PROF_LOG_ERROR_RETURN(pthread_getschedparam(thread, &policy, &param)) == 0) {
        param.sched_priority = 50;
        SENTRY_PROF_LOG_ERROR_RETURN(pthread_setschedparam(thread, policy, &param));
    }

    // give the other thread a little time to spawn, otherwise its metadata doesn't come back as
    // expected
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    const auto cache = std::make_shared<ThreadMetadataCache>();
    ThreadHandle handle(pthread_mach_thread_np(thread));
    XCTAssertEqual(cache->metadataForThread(handle).priority, 50);

    if (SENTRY_PROF_LOG_ERROR_RETURN(pthread_getschedparam(thread, &policy, &param)) == 0) {
        param.sched_priority = 100;
        SENTRY_PROF_LOG_ERROR_RETURN(pthread_setschedparam(thread, policy, &param));
    }
    XCTAssertEqual(cache->metadataForThread(handle).priority, 50);

    XCTAssertEqual(pthread_cancel(thread), 0);
    XCTAssertEqual(pthread_join(thread, nullptr), 0);
}

- (void)testIgnoresSentryOwnedThreads
{
    pthread_t thread;
    char name[] = "io.sentry.SentryThreadMetadataCacheTests";
    XCTAssertEqual(pthread_create(&thread, nullptr, threadSpin, reinterpret_cast<void *>(name)), 0);

    // give the other thread a little time to spawn, otherwise its name comes back as an empty
    // string and the isSentryOwnedThreadName check will fail
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    const auto cache = std::make_shared<ThreadMetadataCache>();
    ThreadHandle handle(pthread_mach_thread_np(thread));
    XCTAssertEqual(cache->metadataForThread(handle).threadID, 0ULL);

    XCTAssertEqual(pthread_cancel(thread), 0);
    XCTAssertEqual(pthread_join(thread, nullptr), 0);
}

- (void)testRetrievesQueueMetadata
{
    const auto label = "io.sentry.SentryThreadMetadataCacheTests.testQueue";
    const auto queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
    const auto cache = std::make_shared<ThreadMetadataCache>();

    const auto address = reinterpret_cast<std::uint64_t>(&queue);
    cache->setQueueMetadata({ address, std::make_shared<std::string>(label) });
    XCTAssertTrue(*cache->metadataForQueue(reinterpret_cast<std::uint64_t>(&queue)).label == label);
}

- (void)testNonexistentQueueAddressReturnsNoMetadata
{
    const auto cache = std::make_shared<ThreadMetadataCache>();
    const auto metadata = cache->metadataForQueue(0);

    XCTAssertEqual(metadata.address, 0ULL);
    XCTAssertEqual(metadata.label, nullptr);
}

@end

#endif
