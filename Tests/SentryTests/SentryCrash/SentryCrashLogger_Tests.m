// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashLogger_Tests.m
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

#import "XCTestCase+SentryCrash.h"
#import <XCTest/XCTest.h>

#import "SentryAsyncSafeLog.h"

@interface SentryCrashLogger_Tests : XCTestCase

@property (nonatomic, readwrite, retain) NSString *tempDir;

@end

@implementation SentryCrashLogger_Tests

@synthesize tempDir = _tempDir;

- (void)setUp
{
    [super setUp];
    self.tempDir = [self createTempPath];
}

- (void)tearDown
{
    [self removePath:self.tempDir];
}

- (void)testLogError
{
    SENTRY_ASYNC_SAFE_LOG_ERROR(@"TEST");
}

- (void)testLogErrorNull
{
    NSString *str = nil;
    SENTRY_ASYNC_SAFE_LOG_ERROR(str);
}

- (void)testLogAlways
{
    SENTRY_ASYNC_SAFE_LOG_ALWAYS(@"TEST");
}

- (void)testLogAlwaysNull
{
    NSString *str = nil;
    SENTRY_ASYNC_SAFE_LOG_ALWAYS(str);
}

- (void)testLogBasicError
{
    SENTRY_ASYNC_SAFE_LOG_BASIC_ERROR(@"TEST");
}

- (void)testLogBasicErrorNull
{
    NSString *str = nil;
    SENTRY_ASYNC_SAFE_LOG_BASIC_ERROR(str);
}

- (void)testLogBasicAlways
{
    SENTRY_ASYNC_SAFE_LOG_BASIC_ALWAYS(@"TEST");
}

- (void)testLogBasicAlwaysNull
{
    NSString *str = nil;
    SENTRY_ASYNC_SAFE_LOG_BASIC_ALWAYS(str);
}

@end
