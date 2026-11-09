#import "SentryDeprecated.h"
#import <XCTest/XCTest.h>

@interface SentryDeprecatedHeaderAPIObjCTests : XCTestCase

@end

@implementation SentryDeprecatedHeaderAPIObjCTests

- (void)testHeaderConstants_shouldMatchWireLiterals
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(SENTRY_BAGGAGE_HEADER, @"baggage");
    XCTAssertEqualObjects(SENTRY_TRACE_HEADER, @"sentry-trace");
    XCTAssertEqualObjects(SENTRY_TRACE_TYPE, @"trace");
#pragma clang diagnostic pop
}

@end
