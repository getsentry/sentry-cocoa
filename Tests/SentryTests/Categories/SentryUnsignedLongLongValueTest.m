#import "NSString+SentryUnsignedLongLongValue.h"
#import "NSNumber+SentryUnsignedLongLongValue.h"
#import <XCTest/XCTest.h>

@interface SentryUnsignedLongLongValueTest : XCTestCase

@end

@implementation SentryUnsignedLongLongValueTest

- (void)testNSStringUnsignedLongLongValue
{
    XCTAssertEqual([@"" sentry_unsignedLongLongValue], 0);
    XCTAssertEqual([@"9" sentry_unsignedLongLongValue], 9);
    XCTAssertEqual([@"99" sentry_unsignedLongLongValue], 99);
    XCTAssertEqual([@"999" sentry_unsignedLongLongValue], 999);

    NSString *longLongMaxValue =
        [NSString stringWithFormat:@"%llu", (unsigned long long)0x7FFFFFFFFFFFFFFF];
    XCTAssertEqual([longLongMaxValue sentry_unsignedLongLongValue], 9223372036854775807);

    NSString *negativelongLongMaxValue =
        [NSString stringWithFormat:@"%llu", (unsigned long long)-0x8000000000000000];
    XCTAssertEqual([negativelongLongMaxValue sentry_unsignedLongLongValue], 0x8000000000000000);

    NSString *unsignedLongLongMaxValue =
        [NSString stringWithFormat:@"%llu", (unsigned long long)0xFFFFFFFFFFFFFFFF];
    XCTAssertEqual([unsignedLongLongMaxValue sentry_unsignedLongLongValue], 0xFFFFFFFFFFFFFFFF);
}

- (void)testNSNumberUnsignedLongLongValue
{
    XCTAssertEqual([[NSNumber new] sentry_unsignedLongLongValue], 0);
    XCTAssertEqual([@(9) sentry_unsignedLongLongValue], 9);
    XCTAssertEqual([@(99) sentry_unsignedLongLongValue], 99);
    XCTAssertEqual([@(999) sentry_unsignedLongLongValue], 999);

    NSNumber *longLongMaxValue =
    [NSNumber numberWithUnsignedLongLong:(unsigned long long)0x7FFFFFFFFFFFFFFF];
    XCTAssertEqual([longLongMaxValue sentry_unsignedLongLongValue], 9223372036854775807);

    NSNumber *negativelongLongMaxValue =
    [NSNumber numberWithUnsignedLongLong:(unsigned long long)-0x8000000000000000];
    XCTAssertEqual([negativelongLongMaxValue sentry_unsignedLongLongValue], 0x8000000000000000);

    NSNumber *unsignedLongLongMaxValue =
    [NSNumber numberWithUnsignedLongLong:(unsigned long long)0xFFFFFFFFFFFFFFFF];
    XCTAssertEqual([unsignedLongLongMaxValue sentry_unsignedLongLongValue], 0xFFFFFFFFFFFFFFFF);
}

@end
