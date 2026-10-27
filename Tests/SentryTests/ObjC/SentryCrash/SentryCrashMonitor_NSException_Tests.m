// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_NSException_Tests.m
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

#if !SDK_V10
#    import <XCTest/XCTest.h>

#    import "SentryCrashMonitorContext.h"
#    include <mach/mach.h>
#    include <pthread.h>
#    include <stdatomic.h>
#    include <unistd.h>
@import _SentryPrivate;
@import SentryTestUtilsObjC;

static thread_t g_probeThread;
static atomic_bool g_stopProbeThread;
static bool g_metadataReadWhileSuspended;
static bool g_threadInfoFailed;
static bool g_probeSuspendedDuringReport;
static char g_capturedName[1024];
static char g_capturedReason[1024];
static char g_capturedUserInfo[1024];
static bool g_reasonWasNull;

static bool
probeThreadIsSuspended(void)
{
    thread_basic_info_data_t info = { 0 };
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    kern_return_t result
        = thread_info(g_probeThread, THREAD_BASIC_INFO, (thread_info_t)&info, &count);
    if (result != KERN_SUCCESS) {
        g_threadInfoFailed = true;
    }
    return info.suspend_count > 0;
}

static void *
runProbeThread(__unused void *context)
{
    while (!atomic_load(&g_stopProbeThread)) {
        usleep(1000);
    }
    return NULL;
}

static void
captureExceptionContext(struct SentryCrash_MonitorContext *context)
{
    // Only C operations here: the monitor has suspended the test runner's other threads.
    g_probeSuspendedDuringReport = probeThreadIsSuspended();
    snprintf(g_capturedName, sizeof(g_capturedName), "%s", context->NSException.name);
    g_reasonWasNull = context->crashReason == NULL;
    snprintf(g_capturedReason, sizeof(g_capturedReason), "%s", context->crashReason ?: "");
    snprintf(g_capturedUserInfo, sizeof(g_capturedUserInfo), "%s", context->NSException.userInfo);
}

@interface SuspensionCheckingUserInfoValue : NSObject
@end

@implementation SuspensionCheckingUserInfoValue

- (NSString *)description
{
    g_metadataReadWhileSuspended |= probeThreadIsSuspended();
    return @"value";
}

@end

@interface SuspensionCheckingException : NSException
@end

@implementation SuspensionCheckingException

- (NSExceptionName)name
{
    g_metadataReadWhileSuspended |= probeThreadIsSuspended();
    return [super name];
}

- (NSString *)reason
{
    g_metadataReadWhileSuspended |= probeThreadIsSuspended();
    return [super reason];
}

- (NSDictionary *)userInfo
{
    g_metadataReadWhileSuspended |= probeThreadIsSuspended();
    return [super userInfo];
}

@end

@interface SentryCrashMonitor_NSException_Tests : XCTestCase
@property (nonatomic, assign) SentryCrashMonitorType previousMonitors;
@property (nonatomic, assign) SentryCrashMonitorEventCallback previousCallback;
@property (nonatomic, assign) NSUncaughtExceptionHandler *previousHandler;
@end

@implementation SentryCrashMonitor_NSException_Tests

- (void)setUp
{
    [super setUp];
    self.previousMonitors = sentrycrashcm_getActiveMonitors();
    self.previousCallback = sentrycrashcm_getEventCallback();
    self.previousHandler = NSGetUncaughtExceptionHandler();
    sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    sentrycrashcm_resetState();
    NSSetUncaughtExceptionHandler(NULL);
    g_metadataReadWhileSuspended = false;
    g_threadInfoFailed = false;
    g_probeSuspendedDuringReport = false;
    g_reasonWasNull = false;
    memset(g_capturedName, 0, sizeof(g_capturedName));
    memset(g_capturedReason, 0, sizeof(g_capturedReason));
    memset(g_capturedUserInfo, 0, sizeof(g_capturedUserInfo));
}

- (void)tearDown
{
    sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    sentrycrashcm_resetState();
    sentrycrashcm_setEventCallback(self.previousCallback);
    sentrycrashcm_setActiveMonitors(self.previousMonitors);
    NSSetUncaughtExceptionHandler(self.previousHandler);
    [super tearDown];
}

- (void)testInstallAndRemove
{
    SentryCrashMonitorAPI *api = sentrycrashcm_nsexception_getAPI();
    api->setEnabled(true);
    XCTAssertTrue(api->isEnabled());
    [NSThread sleepForTimeInterval:0.1];
    api->setEnabled(false);
    XCTAssertFalse(api->isEnabled());
}

- (void)captureException:(NSException *)exception
{
    pthread_t probe;
    atomic_store(&g_stopProbeThread, false);
    int result = pthread_create(&probe, NULL, runProbeThread, NULL);
    XCTAssertEqual(result, 0);
    if (result != 0) {
        return;
    }
    g_probeThread = pthread_mach_thread_np(probe);
    sentrycrashcm_setEventCallback(captureExceptionContext);
    sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNSException);
    NSUncaughtExceptionHandler *handler = NSGetUncaughtExceptionHandler();

    handler(exception);
    atomic_store(&g_stopProbeThread, true);
    pthread_join(probe, NULL);
}

- (void)testHandleException_whenOtherThreadsAreSuspended_shouldPrepareMetadataBeforeSuspension
{
    // -- Arrange --
    NSException *exception = [[SuspensionCheckingException alloc]
        initWithName:@"TestException"
              reason:@"Something went wrong é"
            userInfo:@{ @"detail" : [[SuspensionCheckingUserInfoValue alloc] init] }];

    // -- Act --
    [self captureException:exception];

    // -- Assert --
    XCTAssertFalse(g_threadInfoFailed);
    XCTAssertTrue(g_probeSuspendedDuringReport);
    XCTAssertFalse(g_metadataReadWhileSuspended,
        @"Exception metadata must be extracted before suspending other threads");
    XCTAssertEqual(strcmp(g_capturedName, "TestException"), 0);
    XCTAssertEqual(strcmp(g_capturedReason, "Something went wrong é"), 0);
    XCTAssertEqual(strcmp(g_capturedUserInfo, "{\n    detail = value;\n}"), 0);
    XCTAssertFalse(g_reasonWasNull);
}

- (void)testHandleException_whenMetadataIsNil_shouldPreserveNullRepresentation
{
    // -- Arrange --
    NSException *exception = [[SuspensionCheckingException alloc] initWithName:@"TestException"
                                                                        reason:nil
                                                                      userInfo:nil];

    // -- Act --
    [self captureException:exception];

    // -- Assert --
    XCTAssertFalse(g_threadInfoFailed);
    XCTAssertTrue(g_probeSuspendedDuringReport);
    XCTAssertFalse(g_metadataReadWhileSuspended);
    XCTAssertEqual(strcmp(g_capturedName, "TestException"), 0);
    XCTAssertTrue(g_reasonWasNull);
    XCTAssertEqual(strcmp(g_capturedUserInfo, "(null)"), 0);
}

- (void)testDoubleInstallAndRemove
{
    SentryCrashMonitorAPI *api = sentrycrashcm_nsexception_getAPI();

    api->setEnabled(true);
    XCTAssertTrue(api->isEnabled());
    api->setEnabled(true);
    XCTAssertTrue(api->isEnabled());

    api->setEnabled(false);
    XCTAssertFalse(api->isEnabled());
    api->setEnabled(false);
    XCTAssertFalse(api->isEnabled());
}

@end

#endif // !SDK_V10
