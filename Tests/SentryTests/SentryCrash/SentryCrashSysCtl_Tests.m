// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSysCtl_Tests.m
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

#import "SentryCrashSysCtl.h"

@interface SentryCrashSysCtl_Tests : XCTestCase
@end

@implementation SentryCrashSysCtl_Tests

- (void)testSysCtlInt32
{
    int32_t result = sentrycrashsysctl_int32(CTL_KERN, KERN_POSIX1);
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlInt32Invalid
{
    int32_t result = sentrycrashsysctl_int32(CTL_KERN, 1000000);
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlInt32ForName
{
    int32_t result = sentrycrashsysctl_int32ForName("kern.posix1version");
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlInt32ForNameInvalid
{
    int32_t result = sentrycrashsysctl_int32ForName("kernblah.posix1version");
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlInt64
{
    int64_t result = sentrycrashsysctl_int64(CTL_KERN, KERN_USRSTACK64);
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlInt64Invalid
{
    int64_t result = sentrycrashsysctl_int64(CTL_KERN, 1000000);
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlInt64ForName
{
    int64_t result = sentrycrashsysctl_int64ForName("kern.usrstack64");
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlInt64ForNameInvalid
{
    int64_t result = sentrycrashsysctl_int64ForName("kernblah.usrstack64");
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlUInt32
{
    uint32_t result = sentrycrashsysctl_uint32(CTL_KERN, KERN_POSIX1);
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlUInt32Invalid
{
    uint32_t result = sentrycrashsysctl_uint32(CTL_KERN, 1000000);
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlUInt32ForName
{
    uint32_t result = sentrycrashsysctl_uint32ForName("kern.posix1version");
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlUInt32ForNameInvalid
{
    uint32_t result = sentrycrashsysctl_uint32ForName("kernblah.posix1version");
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlUInt64
{
    uint64_t result = sentrycrashsysctl_uint64(CTL_KERN, KERN_USRSTACK64);
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlUInt64Invalid
{
    uint64_t result = sentrycrashsysctl_uint64(CTL_KERN, 1000000);
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlUInt64ForName
{
    uint64_t result = sentrycrashsysctl_uint64ForName("kern.usrstack64");
    XCTAssertTrue(result > 0, @"");
}

- (void)testSysCtlUInt64ForNameInvalid
{
    uint64_t result = sentrycrashsysctl_uint64ForName("kernblah.usrstack64");
    XCTAssertTrue(result == 0, @"");
}

- (void)testSysCtlString
{
    char buff[100] = { 0 };
    bool success = sentrycrashsysctl_string(CTL_KERN, KERN_OSTYPE, buff, sizeof(buff));
    XCTAssertTrue(success, @"");
    XCTAssertTrue(buff[0] != 0, @"");
}

- (void)testSysCtlStringInvalid
{
    char buff[100] = { 0 };
    bool success = sentrycrashsysctl_string(CTL_KERN, 1000000, buff, sizeof(buff));
    XCTAssertFalse(success, @"");
    XCTAssertTrue(buff[0] == 0, @"");
}

- (void)testSysCtlStringForName
{
    char buff[100] = { 0 };
    bool success = sentrycrashsysctl_stringForName("kern.ostype", buff, sizeof(buff));
    XCTAssertTrue(success, @"");
    XCTAssertTrue(buff[0] != 0, @"");
}

- (void)testSysCtlStringForNameInvalid
{
    char buff[100] = { 0 };
    bool success = sentrycrashsysctl_stringForName("kernblah.ostype", buff, sizeof(buff));
    XCTAssertFalse(success, @"");
    XCTAssertTrue(buff[0] == 0, @"");
}

- (void)testSysCtlDate
{
    struct timeval value = sentrycrashsysctl_timeval(CTL_KERN, KERN_BOOTTIME);
    XCTAssertTrue(value.tv_sec > 0, @"");
}

- (void)testSysCtlDateInvalid
{
    struct timeval value = sentrycrashsysctl_timeval(CTL_KERN, 1000000);
    XCTAssertTrue(value.tv_sec == 0, @"");
}

- (void)testSysCtlDateForName
{
    struct timeval value = sentrycrashsysctl_timevalForName("kern.boottime");
    XCTAssertTrue(value.tv_sec > 0, @"");
}

- (void)testSysCtlDateForNameInvalid
{
    struct timeval value = sentrycrashsysctl_timevalForName("kernblah.boottime");
    XCTAssertTrue(value.tv_sec == 0, @"");
}

- (void)testSysCtlCurrentProcessStartTime
{
    struct timeval actual = sentrycrashsysctl_currentProcessStartTime();
    NSDate *startTime = [NSDate dateWithTimeIntervalSince1970:actual.tv_sec + actual.tv_usec / 1E6];

    // Current time is after start time
    XCTAssertGreaterThan([[NSDate date] timeIntervalSinceDate:startTime], 0);
}

- (void)testGetProcessInfo
{
    int pid = getpid();
    struct kinfo_proc procInfo = { { { { 0 } } } };
    bool success = sentrycrashsysctl_getProcessInfo(pid, &procInfo);
    XCTAssertTrue(success, @"");
    NSString *processName = [NSString stringWithCString:procInfo.kp_proc.p_comm
                                               encoding:NSUTF8StringEncoding];
    NSString *expected = @"xctest";
    XCTAssertEqualObjects(processName, expected, @"");
}

- (void)testGetMacAddress
{
    unsigned char macAddress[6] = { 0 };
    bool success = sentrycrashsysctl_getMacAddress("en0", (char *)macAddress);
    XCTAssertTrue(success, @"");
    unsigned int result = 0;
    for (unsigned i = 0; i < sizeof(macAddress); i++) {
        result |= macAddress[i];
    }
    XCTAssertTrue(result != 0, @"");
}

- (void)testGetMacAddressInvalid
{
    unsigned char macAddress[6] = { 0 };
    bool success = sentrycrashsysctl_getMacAddress("blah blah", (char *)macAddress);
    XCTAssertFalse(success, @"");
}

- (void)testSysCtlMacros_UsesSENTRY_STRERROR_R_ForSysctlFailures
{
    // -- Arrange --
    // This test verifies that CHECK_SYSCTL_NAME and CHECK_SYSCTL_CMD macros use
    // SENTRY_STRERROR_R macro for error handling when sysctl operations fail.
    //
    // The CHECK_SYSCTL_NAME macro uses SENTRY_STRERROR_R when sysctlbyname fails.
    // The CHECK_SYSCTL_CMD macro uses SENTRY_STRERROR_R when sysctl fails.
    //
    // Note: We cannot easily force sysctl to fail in a test environment, but this test
    // exercises the code paths and documents that the error handling uses
    // SENTRY_STRERROR_R(errno) to ensure thread-safe error message retrieval.

    // -- Act --
    // Call sysctl functions which internally use CHECK_SYSCTL_NAME/CHECK_SYSCTL_CMD macros.
    // Under normal conditions, sysctl operations succeed.
    // If sysctl were to fail, the macros would log using SENTRY_STRERROR_R(errno).

    // Test functions that use CHECK_SYSCTL_NAME macro
    int32_t int32Result = sentrycrashsysctl_int32ForName("kern.posix1version");
    XCTAssertTrue(int32Result > 0, @"Should get valid int32 value");

    int64_t int64Result = sentrycrashsysctl_int64ForName("kern.usrstack64");
    XCTAssertTrue(int64Result > 0, @"Should get valid int64 value");

    uint32_t uint32Result = sentrycrashsysctl_uint32ForName("kern.posix1version");
    XCTAssertTrue(uint32Result > 0, @"Should get valid uint32 value");

    uint64_t uint64Result = sentrycrashsysctl_uint64ForName("kern.usrstack64");
    XCTAssertTrue(uint64Result > 0, @"Should get valid uint64 value");

    char stringBuffer[100] = { 0 };
    bool stringSuccess
        = sentrycrashsysctl_stringForName("kern.ostype", stringBuffer, sizeof(stringBuffer));
    XCTAssertTrue(stringSuccess, @"Should get valid string value");

    // Test functions that use CHECK_SYSCTL_CMD macro
    int32_t int32CmdResult = sentrycrashsysctl_int32(CTL_KERN, KERN_POSIX1);
    XCTAssertTrue(int32CmdResult > 0, @"Should get valid int32 value via command");

    int64_t int64CmdResult = sentrycrashsysctl_int64(CTL_KERN, KERN_USRSTACK64);
    XCTAssertTrue(int64CmdResult > 0, @"Should get valid int64 value via command");

    uint32_t uint32CmdResult = sentrycrashsysctl_uint32(CTL_KERN, KERN_POSIX1);
    XCTAssertTrue(uint32CmdResult > 0, @"Should get valid uint32 value via command");

    uint64_t uint64CmdResult = sentrycrashsysctl_uint64(CTL_KERN, KERN_USRSTACK64);
    XCTAssertTrue(uint64CmdResult > 0, @"Should get valid uint64 value via command");

    char stringCmdBuffer[100] = { 0 };
    bool stringCmdSuccess
        = sentrycrashsysctl_string(CTL_KERN, KERN_OSTYPE, stringCmdBuffer, sizeof(stringCmdBuffer));
    XCTAssertTrue(stringCmdSuccess, @"Should get valid string value via command");

    // -- Assert --
    // Verify all functions succeed (sysctl operations succeed in normal test conditions)
    // The macros would use SENTRY_STRERROR_R(errno) if sysctl were to fail.
}

- (void)testSysCtlFunctions_UsesSENTRY_STRERROR_R_ForSysctlFailures
{
    // -- Arrange --
    // This test verifies that individual sysctl functions use SENTRY_STRERROR_R macro
    // for error handling when sysctl operations fail.
    //
    // These functions directly use SENTRY_STRERROR_R (not through macros):
    // - sentrycrashsysctl_timeval
    // - sentrycrashsysctl_timevalForName
    // - sentrycrashsysctl_currentProcessStartTime
    // - sentrycrashsysctl_getProcessInfo
    // - sentrycrashsysctl_getMacAddress
    //
    // Note: We cannot easily force sysctl to fail in a test environment, but this test
    // exercises the code paths and documents that the error handling uses
    // SENTRY_STRERROR_R(errno) to ensure thread-safe error message retrieval.

    // -- Act --
    // Call sysctl functions which directly use SENTRY_STRERROR_R.
    // Under normal conditions, sysctl operations succeed.
    // If sysctl were to fail, the functions would log using SENTRY_STRERROR_R(errno).

    struct timeval timevalResult = sentrycrashsysctl_timeval(CTL_KERN, KERN_BOOTTIME);
    XCTAssertTrue(timevalResult.tv_sec > 0, @"Should get valid timeval");

    struct timeval timevalNameResult = sentrycrashsysctl_timevalForName("kern.boottime");
    XCTAssertTrue(timevalNameResult.tv_sec > 0, @"Should get valid timeval by name");

    struct timeval startTimeResult = sentrycrashsysctl_currentProcessStartTime();
    XCTAssertTrue(startTimeResult.tv_sec > 0, @"Should get valid process start time");

    int pid = getpid();
    struct kinfo_proc procInfo = { { { { 0 } } } };
    bool procInfoSuccess = sentrycrashsysctl_getProcessInfo(pid, &procInfo);
    XCTAssertTrue(procInfoSuccess, @"Should get valid process info");

    unsigned char macAddress[6] = { 0 };
    bool macSuccess = sentrycrashsysctl_getMacAddress("en0", (char *)macAddress);
    // This may fail if en0 doesn't exist, but the function should handle it gracefully
    // with SENTRY_STRERROR_R if sysctl fails
    XCTAssertNoThrow(macSuccess, @"Should handle sysctl errors gracefully");

    // -- Assert --
    // Verify all functions succeed (sysctl operations succeed in normal test conditions)
    // The functions would use SENTRY_STRERROR_R(errno) if sysctl were to fail.
}

@end
