#import <XCTest/XCTest.h>

#import "SentryCrashMachineContext.h"
#import "SentryCrashMachineContext_Apple.h"
#import "TestThread.h"
#import <mach/mach.h>

@interface SentryCrashMachineContextTests : XCTestCase
@end

@implementation SentryCrashMachineContextTests

- (void)testGetContextForThread_NonCrashedContext_DoesNotPopulateThreadList
{
    // Create a test thread
    NSObject *notificationObject = [[NSObject alloc] init];
    TestThread *thread = [[TestThread alloc] init];
    thread.notificationObject = notificationObject;

    XCTestExpectation *exp = [self expectationWithDescription:@"thread started"];
    [NSNotificationCenter.defaultCenter
        addObserverForName:@"io.sentry.test.TestThread.main"
                    object:notificationObject
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull __unused notification) {
                    [NSNotificationCenter.defaultCenter
                        removeObserver:self
                                  name:@"io.sentry.test.TestThread.main"
                                object:notificationObject];
                    [exp fulfill];
                }];

    [thread start];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    kern_return_t kr;
    kr = thread_suspend(thread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"Thread suspension failed");

    // Get context for a non-crashed thread
    SentryCrashMC_NEW_CONTEXT(machineContext);
    bool result = sentrycrashmc_getContextForThread(thread.thread, machineContext, NO);

    XCTAssertTrue(result, @"Failed to get context for thread");
    XCTAssertFalse(
        sentrycrashmc_isCrashedContext(machineContext), @"Should not be marked as crashed context");

    // For non-crashed contexts, thread list should not be populated (will be 0)
    int threadCount = sentrycrashmc_getThreadCount(machineContext);
    XCTAssertEqual(
        threadCount, 0, @"Thread count should be 0 for non-crashed context, got %d", threadCount);

    thread_resume(thread.thread);
    [thread cancel];

    // Wait for thread to finish
    while (![thread isFinished]) {
        [NSThread sleepForTimeInterval:0.01];
    }
}

- (void)testGetContextForThread_WithManyThreads
{
    NSInteger numberOfThreads = 10;
    NSMutableArray<TestThread *> *threads = [NSMutableArray arrayWithCapacity:numberOfThreads];
    NSMutableArray<XCTestExpectation *> *expectations =
        [NSMutableArray arrayWithCapacity:numberOfThreads];

    for (int i = 0; i < numberOfThreads; i++) {
        NSObject *notificationObject = [[NSObject alloc] init];
        TestThread *thread = [[TestThread alloc] init];
        thread.notificationObject = notificationObject;

        XCTestExpectation *exp =
            [self expectationWithDescription:[NSString stringWithFormat:@"thread %d started", i]];
        [expectations addObject:exp];

        [NSNotificationCenter.defaultCenter
            addObserverForName:@"io.sentry.test.TestThread.main"
                        object:notificationObject
                         queue:nil
                    usingBlock:^(NSNotification *_Nonnull __unused notification) {
                        [NSNotificationCenter.defaultCenter
                            removeObserver:self
                                      name:@"io.sentry.test.TestThread.main"
                                    object:notificationObject];
                        [exp fulfill];
                    }];

        [threads addObject:thread];
        [thread start];
    }

    [self waitForExpectations:expectations timeout:2];

    // Suspend the first thread and get its context
    TestThread *firstThread = threads[0];
    kern_return_t kr = thread_suspend(firstThread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"Thread suspension failed");

    // Get context for the crashed thread
    SentryCrashMC_NEW_CONTEXT(machineContext);
    bool result = sentrycrashmc_getContextForThread(firstThread.thread, machineContext, YES);

    XCTAssertTrue(result, @"Failed to get context for thread");

    // Verify that thread list includes all our test threads
    int threadCount = sentrycrashmc_getThreadCount(machineContext);
    XCTAssertTrue(
        threadCount >= 10, @"Thread count should include all test threads, got %d", threadCount);
    XCTAssertTrue(threadCount <= SENTRY_CRASH_MAX_THREADS,
        @"Thread count should not exceed maximum of SENTRY_CRASH_MAX_THREADS, got %d", threadCount);

    // Verify that all our threads are in the list
    for (TestThread *thread in threads) {
        int threadIndex = sentrycrashmc_indexOfThread(machineContext, thread.thread);
        XCTAssertTrue(threadIndex >= 0, @"Thread should be found in the list");
    }

    // Clean up
    thread_resume(firstThread.thread);
    for (TestThread *thread in threads) {
        [thread cancel];
    }

    // Wait for all threads to finish
    for (TestThread *thread in threads) {
        while (![thread isFinished]) {
            [NSThread sleepForTimeInterval:0.01];
        }
    }
}

@end
