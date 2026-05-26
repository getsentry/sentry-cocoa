@import SentryObjC;
@import XCTest;

@interface SentryObjCSpanIdTests : XCTestCase
@end

@implementation SentryObjCSpanIdTests

- (void)testInit_whenCreated_shouldGenerateValidSpanId
{
    // -- Arrange & Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Assert --
    XCTAssertNotNil(spanId);
    XCTAssertNotNil(spanId.sentrySpanIdString);
    XCTAssertEqual(spanId.sentrySpanIdString.length, 16u);
}

- (void)testInitWithUuid_whenValidUuid_shouldReturn16CharString
{
    // -- Arrange --
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"12c2d058-d584-4270-9aa2-eca08bf20986"];

    // -- Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithUuid:uuid];

    // -- Assert --
    XCTAssertNotNil(spanId);
    XCTAssertNotNil(spanId.sentrySpanIdString);
    XCTAssertEqual(spanId.sentrySpanIdString.length, 16u);
}

- (void)testInitWithValue_whenValid_shouldReturnMatchingString
{
    // -- Arrange & Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:@"12c2d058d5844270"];

    // -- Assert --
    XCTAssertNotNil(spanId);
    XCTAssertEqualObjects(spanId.sentrySpanIdString, @"12c2d058d5844270");
}

- (void)testEmpty_whenCalled_shouldReturnAllZeros
{
    // -- Arrange & Act --
    SentryObjCSpanId *emptyId = [SentryObjCSpanId empty];

    // -- Assert --
    XCTAssertNotNil(emptyId);
    XCTAssertEqualObjects(emptyId.sentrySpanIdString, @"0000000000000000");
}

- (void)testInitWithValue_whenInvalid_shouldReturnEmpty
{
    // -- Arrange & Act --
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:@"invalid"];

    // -- Assert --
    XCTAssertNotNil(spanId);
    XCTAssertEqualObjects(spanId.sentrySpanIdString, @"0000000000000000");
}

- (void)testInit_whenCalledTwice_shouldReturnDifferentSpanIds
{
    // -- Arrange & Act --
    SentryObjCSpanId *id1 = [[SentryObjCSpanId alloc] init];
    SentryObjCSpanId *id2 = [[SentryObjCSpanId alloc] init];

    // -- Assert --
    XCTAssertNotEqualObjects(id1.sentrySpanIdString, id2.sentrySpanIdString);
}

@end
