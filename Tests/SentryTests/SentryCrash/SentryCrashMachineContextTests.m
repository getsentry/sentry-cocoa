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
    NSArray<TestThread *> *threads = [self createThreads:1];
    TestThread *thread = threads[0];

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
    [self waitForThreadsToEnd:threads];
}

- (void)testGetContextForThread_WithManyThreads
{
    NSInteger numberOfThreads = 10;
    NSArray<TestThread *> *threads = [self createThreads:numberOfThreads];

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
    XCTAssertTrue(threadCount >= numberOfThreads,
        @"Thread count should include all test threads, got %d", threadCount);
    XCTAssertTrue(threadCount <= SENTRY_CRASH_MAX_THREADS,
        @"Thread count should not exceed maximum of SENTRY_CRASH_MAX_THREADS, got %d", threadCount);

    // Verify that all our threads are in the list
    for (TestThread *thread in threads) {
        int threadIndex = sentrycrashmc_indexOfThread(machineContext, thread.thread);
        XCTAssertTrue(threadIndex >= 0, @"Thread should be found in the list");
    }

    // Clean up
    thread_resume(firstThread.thread);
    [self waitForThreadsToEnd:threads];
}

- (void)testGetContextForThread_WithMoreThan100Threads_IncludesCallingThread
{
    NSInteger numberOfThreads = SENTRY_CRASH_MAX_THREADS + 1;
    NSArray<TestThread *> *threads = [self createThreads:numberOfThreads];

    // Suspend the last thread and get its context
    TestThread *callingThread = threads[SENTRY_CRASH_MAX_THREADS];
    kern_return_t kr = thread_suspend(callingThread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"Thread suspension failed");

    // Get context for the crashed thread
    SentryCrashMC_NEW_CONTEXT(machineContext);
    bool result = sentrycrashmc_getContextForThread(callingThread.thread, machineContext, YES);

    XCTAssertTrue(result, @"Failed to get context for thread");

    // Verify that thread list includes all our test threads
    int threadCount = sentrycrashmc_getThreadCount(machineContext);
    XCTAssertTrue(threadCount >= SENTRY_CRASH_MAX_THREADS,
        @"Thread count should include all test threads, got %d", threadCount);
    XCTAssertTrue(threadCount <= SENTRY_CRASH_MAX_THREADS,
        @"Thread count should not exceed maximum of SENTRY_CRASH_MAX_THREADS, got %d", threadCount);

    // Verify that our crashed thread is in the list
    int threadIndex = sentrycrashmc_indexOfThread(machineContext, callingThread.thread);
    XCTAssertTrue(threadIndex >= 0, @"Thread should be found in the list");

    // Clean up
    thread_resume(callingThread.thread);
    [self waitForThreadsToEnd:threads];
}

- (NSArray<TestThread *> *)createThreads:(NSInteger)numberOfThreads
{
    NSMutableArray<TestThread *> *threads = [NSMutableArray arrayWithCapacity:numberOfThreads];
    XCTestExpectation *startThreadsExpectation = [self expectationWithDescription:@"threads start"];
    startThreadsExpectation.expectedFulfillmentCount = numberOfThreads;

    for (int i = 0; i < numberOfThreads; i++) {
        NSObject *notificationObject = [[NSObject alloc] init];
        TestThread *thread = [[TestThread alloc] init];
        thread.notificationObject = notificationObject;

        [NSNotificationCenter.defaultCenter
            addObserverForName:@"io.sentry.test.TestThread.main"
                        object:notificationObject
                         queue:nil
                    usingBlock:^(NSNotification *_Nonnull __unused notification) {
                        [NSNotificationCenter.defaultCenter
                            removeObserver:self
                                      name:@"io.sentry.test.TestThread.main"
                                    object:notificationObject];
                        [startThreadsExpectation fulfill];
                    }];

        [threads addObject:thread];
        [thread start];
    }

    [self waitForExpectations:@[ startThreadsExpectation ] timeout:5];

    return threads;
}

- (void)waitForThreadsToEnd:(NSArray<TestThread *> *)threads
{
    XCTestExpectation *finishExpectation = [self expectationWithDescription:@"threads finished"];
    finishExpectation.expectedFulfillmentCount = threads.count;
    for (TestThread *thread in threads) {
        thread.endExpectation = finishExpectation;
        [thread cancel];
    }

    // Wait for all threads to finish (up to 10 seconds)
    [self waitForExpectations:@[ finishExpectation ] timeout:10];
}

@end
