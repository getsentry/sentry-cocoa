// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCachedData_Tests.m
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <XCTest/XCTest.h>

#import "SentryCrashCachedData.h"
#import "TestThread.h"

@interface SentryCrashCachedData_Tests : XCTestCase
@end

@implementation SentryCrashCachedData_Tests

- (void)setUp
{
    [super setUp];
    sentrycrashccd_close();
}

// MARK: - Helper

/** Start a named TestThread and wait for it to be running. */
- (TestThread *)startThreadWithName:(NSString *)name
{
    NSObject *notificationObject = [[NSObject alloc] init];
    TestThread *thread = [[TestThread alloc] init];
    thread.notificationObject = notificationObject;
    thread.name = name;

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
    return thread;
}

// MARK: - Tests

- (void)testGetThreadName_whenFrozen_shouldReturnCorrectName
{
    // -- Arrange --
    NSString *expectedName = @"This is a test thread";
    TestThread *thread = [self startThreadWithName:expectedName];

    sentrycrashccd_init(10);
    // Give the background thread time to populate the cache.
    [NSThread sleepForTimeInterval:0.1];

    // -- Act --
    sentrycrashccd_freeze();
    const char *cName = sentrycrashccd_getThreadName(thread.thread);

    // -- Assert --
    XCTAssertTrue(cName != NULL, @"Thread name should not be NULL");
    NSString *name = [NSString stringWithUTF8String:cName];
    XCTAssertEqualObjects(name, expectedName);

    sentrycrashccd_unfreeze();
    [thread cancel];
}

- (void)testGetThreadName_whenNotFrozen_shouldReturnNil
{
    // -- Arrange --
    TestThread *thread = [self startThreadWithName:@"Some thread"];

    sentrycrashccd_init(10);
    [NSThread sleepForTimeInterval:0.1];

    // -- Act --
    // Do NOT call freeze — readers should get NULL from the frozen cache.
    const char *cName = sentrycrashccd_getThreadName(thread.thread);

    // -- Assert --
    XCTAssertTrue(cName == NULL, @"Thread name should be NULL when cache is not frozen");

    [thread cancel];
}

- (void)testGetThreadName_whenUnknownThread_shouldReturnNil
{
    // -- Arrange --
    sentrycrashccd_init(10);
    [NSThread sleepForTimeInterval:0.1];

    // -- Act --
    sentrycrashccd_freeze();
    // Use an invalid thread ID that cannot match any real thread.
    const char *cName = sentrycrashccd_getThreadName((SentryCrashThread)UINTPTR_MAX);

    // -- Assert --
    XCTAssertTrue(cName == NULL, @"Thread name should be NULL for unknown thread");

    sentrycrashccd_unfreeze();
}

- (void)testInit_whenCalledTwice_shouldNotCrash
{
    // -- Act --
    sentrycrashccd_init(10);
    sentrycrashccd_init(10);

    // -- Assert --
    // No crash, and the cache thread is running.
    XCTAssertTrue(sentrycrashccd_hasThreadStarted());
}

- (void)testClose_whenReinitializing_shouldReturnThreadName
{
    // -- Arrange --
    NSString *expectedName = @"Reinitialized thread";
    sentrycrashccd_init(10);
    sentrycrashccd_close();
    XCTAssertFalse(sentrycrashccd_hasThreadStarted());

    TestThread *thread = [self startThreadWithName:expectedName];

    // -- Act --
    sentrycrashccd_init(10);
    [NSThread sleepForTimeInterval:0.1];

    sentrycrashccd_freeze();
    const char *cName = sentrycrashccd_getThreadName(thread.thread);

    // -- Assert --
    XCTAssertTrue(sentrycrashccd_hasThreadStarted());
    XCTAssertTrue(cName != NULL, @"Thread name should be available after reinit");
    NSString *name = [NSString stringWithUTF8String:cName];
    XCTAssertEqualObjects(name, expectedName);

    sentrycrashccd_unfreeze();
    [thread cancel];
}

- (void)testUnfreeze_whenNotFrozen_shouldNotCrash
{
    // -- Arrange --
    sentrycrashccd_init(10);

    // -- Act & Assert --
    // Calling unfreeze without a prior freeze should not crash or corrupt state.
    sentrycrashccd_unfreeze();

    // Verify normal operation still works afterwards.
    [NSThread sleepForTimeInterval:0.1];
    sentrycrashccd_freeze();
    XCTAssertTrue(sentrycrashccd_hasThreadStarted());
    sentrycrashccd_unfreeze();
}

- (void)testFreeze_whenCalledTwiceWithoutUnfreeze_shouldPreserveFrozenCache
{
    // -- Arrange --
    // Simulates a recrash scenario: the first crash calls freeze() inside
    // writeStandardReport, but before unfreeze() is reached a second crash
    // triggers writeRecrashReport which calls freeze() again.
    NSString *expectedName = @"Recrash thread";
    TestThread *thread = [self startThreadWithName:expectedName];

    sentrycrashccd_init(10);
    [NSThread sleepForTimeInterval:0.1];

    // -- Act --
    // First freeze (simulates writeStandardReport path).
    sentrycrashccd_freeze();

    // Verify the cache is valid after first freeze.
    const char *nameAfterFirstFreeze = sentrycrashccd_getThreadName(thread.thread);
    XCTAssertTrue(
        nameAfterFirstFreeze != NULL, @"Thread name should be available after first freeze");

    // Second freeze without unfreeze (simulates the recrash path).
    sentrycrashccd_freeze();

    // -- Assert --
    // The frozen cache should still be valid — the second freeze must not
    // overwrite it with NULL.
    const char *nameAfterSecondFreeze = sentrycrashccd_getThreadName(thread.thread);
    XCTAssertTrue(nameAfterSecondFreeze != NULL,
        @"Thread name should still be available after nested freeze (recrash scenario)");
    NSString *name = [NSString stringWithUTF8String:nameAfterSecondFreeze];
    XCTAssertEqualObjects(name, expectedName);

    sentrycrashccd_unfreeze();
    [thread cancel];
}

- (void)testFreezeUnfreeze_whenCycledMultipleTimes_shouldReturnConsistentResults
{
    // -- Arrange --
    NSString *expectedName = @"Cycling thread";
    TestThread *thread = [self startThreadWithName:expectedName];

    sentrycrashccd_init(10);
    [NSThread sleepForTimeInterval:0.1];

    // -- Act & Assert --
    // Multiple freeze/unfreeze cycles should always return the same thread name.
    for (int i = 0; i < 5; i++) {
        sentrycrashccd_freeze();
        const char *cName = sentrycrashccd_getThreadName(thread.thread);
        XCTAssertTrue(cName != NULL, @"Cycle %d: thread name should not be NULL", i);
        NSString *name = [NSString stringWithUTF8String:cName];
        XCTAssertEqualObjects(name, expectedName, @"Cycle %d: name mismatch", i);
        sentrycrashccd_unfreeze();
    }

    [thread cancel];
}

@end
