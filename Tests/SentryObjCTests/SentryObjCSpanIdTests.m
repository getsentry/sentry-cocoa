#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCSpanIdTests : XCTestCase
@end

@implementation SentryObjCSpanIdTests

- (void)testInit_shouldGenerate16CharHexString
{
    // -- Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Assert --
    XCTAssertEqual(spanId.sentrySpanIdString.length, 16u);
}

- (void)testInitWithUuid_shouldReturnFirst16HexChars
{
    // -- Arrange --
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"12c2d058-d584-4270-9aa2-eca08bf20986"];

    // -- Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithUuid:uuid];

    // -- Assert --
    XCTAssertEqualObjects(spanId.sentrySpanIdString, @"12c2d058d5844270");
}

- (void)testInitWithValue_whenValid_shouldReturnMatchingString
{
    // -- Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:@"12c2d058d5844270"];

    // -- Assert --
    XCTAssertEqualObjects(spanId.sentrySpanIdString, @"12c2d058d5844270");
}

- (void)testEmpty_shouldReturnAllZeros
{
    // -- Act --
    SentryObjCSpanId *emptyId = [SentryObjCSpanId empty];

    // -- Assert --
    XCTAssertEqualObjects(emptyId.sentrySpanIdString, @"0000000000000000");
}

- (void)testInitWithValue_whenInvalid_shouldReturnEmpty
{
    // -- Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:@"invalid"];

    // -- Assert --
    XCTAssertEqualObjects(spanId.sentrySpanIdString, @"0000000000000000");
}

- (void)testInit_whenCalledTwice_shouldReturnDifferentSpanIds
{
    // -- Act --
    SentryObjCSpanId *id1 = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *id2 = [[SentryObjCSpanId alloc] init];

    // -- Assert --
    XCTAssertNotEqualObjects(id1.sentrySpanIdString, id2.sentrySpanIdString);
}

@end
