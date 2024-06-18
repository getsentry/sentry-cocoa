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
sentryLogDebugWithMacroArgsNotEvaluated(SentryLog *logger)
{
    SENTRY_LOG_DEBUG_WITH_LOGGER(logger, @"%@", doNotCallMe());
}

void
sentryLogErrorWithMacro(NSString *message, SentryLog *logger)
{
    SENTRY_LOG_ERROR_WITH_LOGGER(logger, @"%@", message);
}
