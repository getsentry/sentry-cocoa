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


#import <XCTest/XCTest.h>
#import "XCTestCase+SentryCrash.h"

#import "SentryCrashLogger.h"


@interface SentryCrashLogger_Tests : XCTestCase

@property(nonatomic, readwrite, retain) NSString* tempDir;

@end


@implementation SentryCrashLogger_Tests

@synthesize tempDir = _tempDir;

- (void) setUp
{
    [super setUp];
    self.tempDir = [self createTempPath];
}

- (void) tearDown
{
    [self removePath:self.tempDir];
}

- (void) testLogError
{
    SentryCrashLOG_ERROR(@"TEST");
}

- (void) testLogErrorNull
{
    NSString* str = nil;
    SentryCrashLOG_ERROR(str);
}

- (void) testLogAlways
{
    SentryCrashLOG_ALWAYS(@"TEST");
}

- (void) testLogAlwaysNull
{
    NSString* str = nil;
    SentryCrashLOG_ALWAYS(str);
}

- (void) testLogBasicError
{
    SentryCrashLOGBASIC_ERROR(@"TEST");
}

- (void) testLogBasicErrorNull
{
    NSString* str = nil;
    SentryCrashLOGBASIC_ERROR(str);
}

- (void) testLogBasicAlways
{
    SentryCrashLOGBASIC_ALWAYS(@"TEST");
}

- (void) testLogBasicAlwaysNull
{
    NSString* str = nil;
    SentryCrashLOGBASIC_ALWAYS(str);
}

- (void) testSetLogFilename
{
    NSString* expected = @"TEST";
    NSString* logFileName = [self.tempDir stringByAppendingPathComponent:@"log.txt"];
    sentrycrashlog_setLogFilename([logFileName UTF8String], true);
    SentryCrashLOGBASIC_ALWAYS(expected);
    sentrycrashlog_setLogFilename(nil, true);

    NSError* error = nil;
    NSString* result = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"");
    result = [[result componentsSeparatedByString:@"\x0a"] objectAtIndex:0];
    XCTAssertEqualObjects(result, expected, @"");

    SentryCrashLOGBASIC_ALWAYS(@"blah blah");
    result = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    result = [[result componentsSeparatedByString:@"\x0a"] objectAtIndex:0];
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, expected, @"");
}

- (void) testAtomicLogging
{
	NSString* expected = @"0123456789012345678901234567890123456789";
    NSString* logFileName = [self.tempDir stringByAppendingPathComponent:@"atomiclog.txt"];
    sentrycrashlog_setLogFilename([logFileName UTF8String], true);

	dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
	dispatch_queue_t queue = dispatch_queue_create("io.sentry.atomiclogtest", attr);
	dispatch_group_t group = dispatch_group_create();
	
	#define kNumThreads 10
	#define kNumIterations 10
	#define kTimeout 1.0

	for (int i = 0; i < kNumThreads; i++) {
		dispatch_group_enter(group);
		dispatch_async(queue, ^{
			for (int j = 0; j < kNumIterations; j++) {
				SentryCrashLOGBASIC_ALWAYS(expected);
			}
			dispatch_group_leave(group);
		});
	}
	dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, kTimeout * NSEC_PER_SEC));
    sentrycrashlog_setLogFilename(nil, true);

    NSError* error = nil;
    NSString* result = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"");
	result = [result substringToIndex:result.length-1]; // trim the final newline
    NSArray<NSString *> *lines = [result componentsSeparatedByString:@"\n"];
	for (int i = 0; i < (int)lines.count; i++) {
		XCTAssertEqualObjects(lines[i], expected, @"line: %d", i);
	}
	int count = (kNumThreads * kNumIterations);
	XCTAssertEqual(count, (int)lines.count);
}

@end
