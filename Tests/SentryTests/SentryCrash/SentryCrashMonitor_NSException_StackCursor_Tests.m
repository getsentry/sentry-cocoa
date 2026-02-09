// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_NSException_StackCursor_Tests.m
//
//  Created by Karl Stenerud on 2013-01-26.
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

#import "SentryCrashMonitor_NSException_StackCursor.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_Backtrace.h"
#import "SentryCrashStackCursor_SelfThread.h"

@interface SentryCrashMonitor_NSException_StackCursor_Tests : XCTestCase
@end

@implementation SentryCrashMonitor_NSException_StackCursor_Tests

- (void)testExceptionWithEmptyCallStackReturnAddresses_CapturesCurrentThreadStack
{
    // -- Arrange --
    // Create an exception without raising it, so callStackReturnAddresses is empty
    NSException *exception = [NSException exceptionWithName:NSInternalInconsistencyException
                                                     reason:@"Test exception"
                                                   userInfo:nil];

    NSArray *addresses = [exception callStackReturnAddresses];
    XCTAssertEqual(
        addresses.count, 0, "Exception should have empty callStackReturnAddresses when not raised");

    // -- Act --
    SentryCrashStackCursor cursor;
    sentrycrashcm_nsexception_initStackCursor(&cursor, exception);

    // -- Assert --
    XCTAssertTrue(cursor.advanceCursor(&cursor), "Should be able to advance stack cursor");
    XCTAssertTrue(cursor.stackEntry.address > 0, "Should have stackEntry.addresses");

    int frameCount = 1; // Already advanced once
    while (cursor.advanceCursor(&cursor)) {
        XCTAssertTrue(cursor.stackEntry.address > 0, "Stack frame address should be valid");
        frameCount++;
    }
    XCTAssertGreaterThanOrEqual(
        frameCount, 1, "Should have captured at least one stack frame from current thread");
}

- (void)testExceptionWithCallStackReturnAddresses_UsesExceptionStackTrace
{
    // -- Arrange --
    NSException *caughtException = nil;

    // Raise and catch an exception to populate callStackReturnAddresses
    @try {
        NSException *exception = [NSException exceptionWithName:NSInternalInconsistencyException
                                                         reason:@"Test exception for stack trace"
                                                       userInfo:nil];
        [exception raise];
    } @catch (NSException *exception) {
        caughtException = exception;
    }

    XCTAssertNotNil(caughtException, "Should have caught the exception");
    NSArray *addresses = [caughtException callStackReturnAddresses];
    XCTAssertGreaterThan(
        addresses.count, 0, "Raised exception should have callStackReturnAddresses");

    // -- Act --
    SentryCrashStackCursor cursor;
    uintptr_t *callstack = sentrycrashcm_nsexception_initStackCursor(&cursor, caughtException);

    // -- Assert --
    XCTAssertTrue(
        callstack != NULL, "Should return callstack pointer when exception has addresses");
    XCTAssertTrue(cursor.advanceCursor(&cursor),
        "Should be able to advance stack cursor when valid addresses exist");
    XCTAssertTrue(cursor.stackEntry.address > 0, "Should have stackEntry.address");

    NSUInteger expectedFrameCount = addresses.count;
    int frameCount = 1; // Already advanced once
    while (cursor.advanceCursor(&cursor)) {
        XCTAssertTrue(cursor.stackEntry.address > 0, "Stack frame address should be valid");
        frameCount++;
    }
    XCTAssertEqual((NSUInteger)frameCount, expectedFrameCount,
        "Cursor should expose exactly the frames from exception callStackReturnAddresses");

    // Cleanup
    if (callstack != NULL) {
        free(callstack);
    }
}

@end
