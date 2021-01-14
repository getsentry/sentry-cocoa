#import "SentryLog.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryLogTests : XCTestCase

@end

@implementation SentryLogTests

- (void)testLogTypes
{
    [SentryLog logWithMessage:@"1" andLevel:kSentryLogLevelError];
    [SentryLog logWithMessage:@"2" andLevel:kSentryLogLevelDebug];
    [SentryLog logWithMessage:@"3" andLevel:kSentryLogLevelVerbose];
    [SentryLog logWithMessage:@"4" andLevel:kSentryLogLevelNone];
}

@end
