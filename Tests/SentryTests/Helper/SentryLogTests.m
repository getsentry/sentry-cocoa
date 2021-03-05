#import "SentryLog.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryLogTests : XCTestCase

@end

@implementation SentryLogTests

- (void)testLogTypes
{
    [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];

    [SentryLog logWithMessage:@"0" andLevel:kSentryLevelNone];
    [SentryLog logWithMessage:@"1" andLevel:kSentryLevelDebug];
    [SentryLog logWithMessage:@"2" andLevel:kSentryLevelInfo];
    [SentryLog logWithMessage:@"3" andLevel:kSentryLevelWarning];
    [SentryLog logWithMessage:@"4" andLevel:kSentryLevelError];
    [SentryLog logWithMessage:@"5" andLevel:kSentryLevelFatal];
}

@end
