#import "SentryAsyncSafeLog.h"
#import <XCTest/XCTest.h>

@interface SentryAsyncSafeLog : XCTestCase

@end

@implementation SentryAsyncSafeLog

#if SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE

/*
 * This test only runs when SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE is set to 1. We must only
 * set SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE to 1 for debugging purposes but we MUST never
 * commit this change to the main branch.
 */
- (void)testAsyncSafeLogDoesNotWriteToConsole
{
    XCTFail(@"SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE must not be set to 1, because it "
            @"compromises async safety. You must only use it for debugging purposes. See "
            @"SentryAsyncSafeLog.h for more context.");
}

#endif // SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE

@end
