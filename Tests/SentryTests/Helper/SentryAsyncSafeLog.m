#import "SentryAsyncSafeLog.h"
#import <XCTest/XCTest.h>

@interface SentryAsyncSafeLog : XCTestCase

@end

@implementation SentryAsyncSafeLog

#if SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE

- (void)testAsyncSafeLogDoesNotWriteToConsole
{
    XCTFail(@"SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE must not be set to 1, because it "
            @"compromises async safety. You must only use it for debugging purposes.");
}

#endif // SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE

@end
