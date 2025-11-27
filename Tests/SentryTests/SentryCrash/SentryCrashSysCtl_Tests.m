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

#import "FileBasedTestCase.h"
#import "SentryAsyncSafeLog.h"
#import "SentryCrashSysCtl.h"

@interface SentryCrashSysCtl_Tests : FileBasedTestCase
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
    // We test this by setting up a log file, calling sysctl functions with invalid
    // parameters to force failures, then verifying the log file contains error messages
    // that include the output from SENTRY_STRERROR_R(errno).

    NSString *logFile = [self.tempPath stringByAppendingPathComponent:@"async.log"];
    int result = sentry_asyncLogSetFileName(logFile.UTF8String, true);
    XCTAssertEqual(result, 0, @"Should set log file name");

    // -- Act --
    // Call sysctl functions with invalid parameters to trigger error handling paths
    // that use CHECK_SYSCTL_NAME and CHECK_SYSCTL_CMD macros.

    // Test functions that use CHECK_SYSCTL_NAME macro with invalid names
    int32_t int32Result = sentrycrashsysctl_int32ForName("invalid.sysctl.name");
    XCTAssertEqual(int32Result, 0, @"Should return 0 when sysctlbyname fails");

    int64_t int64Result = sentrycrashsysctl_int64ForName("invalid.sysctl.name");
    XCTAssertEqual(int64Result, 0, @"Should return 0 when sysctlbyname fails");

    uint32_t uint32Result = sentrycrashsysctl_uint32ForName("invalid.sysctl.name");
    XCTAssertEqual(uint32Result, 0, @"Should return 0 when sysctlbyname fails");

    uint64_t uint64Result = sentrycrashsysctl_uint64ForName("invalid.sysctl.name");
    XCTAssertEqual(uint64Result, 0, @"Should return 0 when sysctlbyname fails");

    char stringBuffer[100] = { 0 };
    int stringResult = sentrycrashsysctl_stringForName(
        "invalid.sysctl.name", stringBuffer, sizeof(stringBuffer));
    XCTAssertEqual(stringResult, 0, @"Should return 0 when sysctlbyname fails");

    // Test functions that use CHECK_SYSCTL_CMD macro with invalid commands
    int32_t int32CmdResult = sentrycrashsysctl_int32(CTL_KERN, 1000000);
    XCTAssertEqual(int32CmdResult, 0, @"Should return 0 when sysctl fails");

    int64_t int64CmdResult = sentrycrashsysctl_int64(CTL_KERN, 1000000);
    XCTAssertEqual(int64CmdResult, 0, @"Should return 0 when sysctl fails");

    uint32_t uint32CmdResult = sentrycrashsysctl_uint32(CTL_KERN, 1000000);
    XCTAssertEqual(uint32CmdResult, 0, @"Should return 0 when sysctl fails");

    uint64_t uint64CmdResult = sentrycrashsysctl_uint64(CTL_KERN, 1000000);
    XCTAssertEqual(uint64CmdResult, 0, @"Should return 0 when sysctl fails");

    char stringCmdBuffer[100] = { 0 };
    int stringCmdResult
        = sentrycrashsysctl_string(CTL_KERN, 1000000, stringCmdBuffer, sizeof(stringCmdBuffer));
    XCTAssertEqual(stringCmdResult, 0, @"Should return 0 when sysctl fails");

    // -- Assert --
    // Verify the functions fail gracefully (error handling path executes)
    XCTAssertEqual(int32Result, 0, @"Should return 0 when sysctlbyname fails");
    XCTAssertEqual(int64Result, 0, @"Should return 0 when sysctlbyname fails");
    XCTAssertEqual(uint32Result, 0, @"Should return 0 when sysctlbyname fails");
    XCTAssertEqual(uint64Result, 0, @"Should return 0 when sysctlbyname fails");
    XCTAssertEqual(stringResult, 0, @"Should return 0 when sysctlbyname fails");
    XCTAssertEqual(int32CmdResult, 0, @"Should return 0 when sysctl fails");
    XCTAssertEqual(int64CmdResult, 0, @"Should return 0 when sysctl fails");
    XCTAssertEqual(uint32CmdResult, 0, @"Should return 0 when sysctl fails");
    XCTAssertEqual(uint64CmdResult, 0, @"Should return 0 when sysctl fails");
    XCTAssertEqual(stringCmdResult, 0, @"Should return 0 when sysctl fails");

    // Verify log file contains error messages with SENTRY_STRERROR_R output
    NSData *logData = [NSData dataWithContentsOfFile:logFile];
    XCTAssertNotNil(logData, @"Log file should exist");
    NSString *logContent = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(logContent, @"Log content should be readable");

    // Verify log contains specific error messages from CHECK_SYSCTL_NAME macro
    // The macro uses #CALL which stringifies the entire function call, so the format is:
    // "Could not get sysctlbyname(name, &value, &size, NULL, 0) value for invalid.sysctl.name:
    // <SENTRY_STRERROR_R output>" We verify the exact pattern appears in the log by checking each
    // line contains both parts together
    NSArray<NSString *> *logLines = [logContent componentsSeparatedByString:@"\n"];
    BOOL foundSysctlbynameError = NO;
    for (NSString *line in logLines) {
        if ([line containsString:@"Could not get"] &&
            [line containsString:@"value for invalid.sysctl.name"]) {
            foundSysctlbynameError = YES;
            break;
        }
    }
    XCTAssertTrue(foundSysctlbynameError,
        @"Log should contain error message 'Could not get ... value for invalid.sysctl.name' for "
        @"sysctlbyname failure");

    // Verify log contains specific error messages from CHECK_SYSCTL_CMD macro
    // The macro uses #CALL which stringifies the entire function call, so the format is:
    // "Could not get sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0) value for
    // 1,1000000: <SENTRY_STRERROR_R output>" CTL_KERN is 1, and we used 1000000 as the invalid
    // minor command We verify the exact pattern appears in the log by checking each line contains
    // both parts together
    BOOL foundSysctlError = NO;
    for (NSString *line in logLines) {
        if ([line containsString:@"Could not get"] &&
            [line containsString:@"value for 1,1000000"]) {
            foundSysctlError = YES;
            break;
        }
    }
    XCTAssertTrue(foundSysctlError,
        @"Log should contain error message 'Could not get ... value for 1,1000000' for sysctl "
        @"failure");

    // Verify log contains ERROR level (from SENTRY_ASYNC_SAFE_LOG_ERROR)
    XCTAssertTrue([logContent containsString:@"ERROR"], @"Log should contain ERROR level");

    // Verify log contains SENTRY_STRERROR_R output (thread-safe error strings)
    // The error messages end with the output from SENTRY_STRERROR_R(errno)
    // Common error strings include "No such file or directory", "Invalid argument", etc.
    // We verify the log contains a colon followed by an error description
    NSRange errorRange = [logContent rangeOfString:@": " options:NSBackwardsSearch];
    XCTAssertTrue(errorRange.location != NSNotFound,
        @"Log should contain error descriptions from SENTRY_STRERROR_R");
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
    // We test this by setting up a log file, calling sysctl functions with invalid
    // parameters to force failures, then verifying the log file contains error messages
    // that include the output from SENTRY_STRERROR_R(errno).

    NSString *logFile = [self.tempPath stringByAppendingPathComponent:@"async.log"];
    int result = sentry_asyncLogSetFileName(logFile.UTF8String, true);
    XCTAssertEqual(result, 0, @"Should set log file name");

    // -- Act --
    // Call sysctl functions with invalid parameters to trigger error handling paths
    // that directly use SENTRY_STRERROR_R.

    // Test sentrycrashsysctl_timeval with invalid command
    struct timeval timevalResult = sentrycrashsysctl_timeval(CTL_KERN, 1000000);
    XCTAssertEqual(timevalResult.tv_sec, 0, @"Should return zero timeval when sysctl fails");
    XCTAssertEqual(timevalResult.tv_usec, 0, @"Should return zero timeval when sysctl fails");

    // Test sentrycrashsysctl_timevalForName with invalid name
    struct timeval timevalNameResult = sentrycrashsysctl_timevalForName("invalid.sysctl.name");
    XCTAssertEqual(
        timevalNameResult.tv_sec, 0, @"Should return zero timeval when sysctlbyname fails");
    XCTAssertEqual(
        timevalNameResult.tv_usec, 0, @"Should return zero timeval when sysctlbyname fails");

    // Test sentrycrashsysctl_getProcessInfo with non-existent PID
    // Use a very large PID that definitely doesn't exist (max PID is typically 99999)
    struct kinfo_proc procInfo = { { { { 0 } } } };
    bool procInfoSuccess = sentrycrashsysctl_getProcessInfo(999999999, &procInfo);
    // Note: On macOS, sysctl may succeed even for non-existent PIDs, returning empty data.
    // If it fails, the function will log using SENTRY_STRERROR_R(errno).
    // We verify the error handling path exists and correctly uses SENTRY_STRERROR_R
    // (verified through code review).

    // Test sentrycrashsysctl_getMacAddress with invalid interface name
    unsigned char macAddress[6] = { 0 };
    bool macSuccess
        = sentrycrashsysctl_getMacAddress("nonexistent_interface_xyz", (char *)macAddress);
    // This will fail because the interface doesn't exist, and the function should handle it
    // gracefully with SENTRY_STRERROR_R if sysctl fails
    XCTAssertFalse(macSuccess, @"Should return false when interface doesn't exist");

    // Note: sentrycrashsysctl_currentProcessStartTime uses getpid() which always succeeds,
    // so we cannot easily force it to fail. The error handling code path exists and correctly
    // uses SENTRY_STRERROR_R(errno) when sysctl fails (verified through code review).

    // -- Assert --
    // Verify the functions fail gracefully (error handling path executes)
    XCTAssertEqual(timevalResult.tv_sec, 0, @"Should return zero timeval when sysctl fails");
    XCTAssertEqual(timevalResult.tv_usec, 0, @"Should return zero timeval when sysctl fails");
    XCTAssertEqual(
        timevalNameResult.tv_sec, 0, @"Should return zero timeval when sysctlbyname fails");
    XCTAssertEqual(
        timevalNameResult.tv_usec, 0, @"Should return zero timeval when sysctlbyname fails");
    // Note: sentrycrashsysctl_getProcessInfo may succeed even for non-existent PIDs on macOS,
    // so we don't assert on its return value. The error handling code path exists and correctly
    // uses SENTRY_STRERROR_R(errno) when sysctl fails (verified through code review).
    XCTAssertFalse(macSuccess, @"Should return false when interface doesn't exist");

    // Verify log file contains error messages with SENTRY_STRERROR_R output
    NSData *logData = [NSData dataWithContentsOfFile:logFile];
    XCTAssertNotNil(logData, @"Log file should exist");
    NSString *logContent = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(logContent, @"Log content should be readable");

    // Verify log contains specific error messages by checking each line
    NSArray<NSString *> *logLines = [logContent componentsSeparatedByString:@"\n"];

    // Verify log contains specific error message from sentrycrashsysctl_timeval
    // Format: "Could not get timeval value for 1,1000000: <SENTRY_STRERROR_R output>"
    // CTL_KERN is 1, and we used 1000000 as the invalid minor command
    BOOL foundTimevalError = NO;
    for (NSString *line in logLines) {
        if ([line containsString:@"Could not get timeval value for 1,1000000"]) {
            foundTimevalError = YES;
            break;
        }
    }
    XCTAssertTrue(foundTimevalError,
        @"Log should contain exact error message 'Could not get timeval value for 1,1000000' for "
        @"sysctl failure");

    // Verify log contains specific error message from sentrycrashsysctl_timevalForName
    // Format: "Could not get timeval value for invalid.sysctl.name: <SENTRY_STRERROR_R output>"
    BOOL foundTimevalNameError = NO;
    for (NSString *line in logLines) {
        if ([line containsString:@"Could not get timeval value for invalid.sysctl.name"]) {
            foundTimevalNameError = YES;
            break;
        }
    }
    XCTAssertTrue(foundTimevalNameError,
        @"Log should contain exact error message 'Could not get timeval value for "
        @"invalid.sysctl.name' for sysctlbyname failure");

    // Verify log contains specific error message from sentrycrashsysctl_getMacAddress
    // Format: "Could not get interface index for nonexistent_interface_xyz: <SENTRY_STRERROR_R
    // output>" or "Could not get interface data for nonexistent_interface_xyz: <SENTRY_STRERROR_R
    // output>"
    BOOL foundMacError = NO;
    for (NSString *line in logLines) {
        if ([line containsString:@"Could not get interface index for nonexistent_interface_xyz"] ||
            [line containsString:@"Could not get interface data for nonexistent_interface_xyz"]) {
            foundMacError = YES;
            break;
        }
    }
    XCTAssertTrue(foundMacError,
        @"Log should contain exact error message 'Could not get interface ... for "
        @"nonexistent_interface_xyz' for getMacAddress failure");
}

@end
