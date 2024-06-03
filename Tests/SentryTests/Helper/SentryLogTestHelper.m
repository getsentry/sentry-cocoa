#import "SentryLogTestHelper.h"
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

NSString *
doNotCallMe(void)
{
    XCTFail("The args for the log macro must not be evaluated.");
    return @"Don't call me";
}

void
sentryLogDebugWithMacroArgsNotEvaluated(void)
{
    SENTRY_LOG_DEBUG(@"%@", doNotCallMe());
}

void
sentryLogErrorWithMacro(NSString *message)
{
    SENTRY_LOG_ERROR(@"%@", message);
}
