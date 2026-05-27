#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCIdTests : XCTestCase
@end

@implementation SentryObjCIdTests

- (void)testInit_whenCreated_shouldGenerateValidId
{
    // -- Arrange & Act --
    SentryObjCId *sentryId = [[SentryObjCId alloc] init];

    // -- Assert --
    XCTAssertNotNil(sentryId);
    XCTAssertNotNil(sentryId.sentryIdString);
    XCTAssertEqual(sentryId.sentryIdString.length, 32u);
}

- (void)testInitWithUuid_whenValidUuid_shouldReturnMatchingString
{
    // -- Arrange --
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"12c2d058-d584-4270-9aa2-eca08bf20986"];

    // -- Act --
    SentryObjCId *sentryId = [[SentryObjCId alloc] initWithUuid:uuid];

    // -- Assert --
    XCTAssertNotNil(sentryId);
    XCTAssertEqualObjects(sentryId.sentryIdString, @"12c2d058d58442709aa2eca08bf20986");
}

- (void)testInitWithUUIDString_whenNoDashes_shouldReturnMatchingString
{
    // -- Arrange & Act --
    SentryObjCId *sentryId =
        [[SentryObjCId alloc] initWithUUIDString:@"12c2d058d58442709aa2eca08bf20986"];

    // -- Assert --
    XCTAssertNotNil(sentryId);
    XCTAssertEqualObjects(sentryId.sentryIdString, @"12c2d058d58442709aa2eca08bf20986");
}

- (void)testInitWithUUIDString_whenWithDashes_shouldReturnMatchingString
{
    // -- Arrange & Act --
    SentryObjCId *sentryId =
        [[SentryObjCId alloc] initWithUUIDString:@"12c2d058-d584-4270-9aa2-eca08bf20986"];

    // -- Assert --
    XCTAssertNotNil(sentryId);
    XCTAssertEqualObjects(sentryId.sentryIdString, @"12c2d058d58442709aa2eca08bf20986");
}

- (void)testEmpty_whenCalled_shouldReturnAllZeros
{
    // -- Arrange & Act --
    SentryObjCId *emptyId = [SentryObjCId empty];

    // -- Assert --
    XCTAssertNotNil(emptyId);
    XCTAssertEqualObjects(emptyId.sentryIdString, @"00000000000000000000000000000000");
}

- (void)testInitWithUUIDString_whenInvalid_shouldReturnEmpty
{
    // -- Arrange & Act --
    SentryObjCId *sentryId = [[SentryObjCId alloc] initWithUUIDString:@"not-a-valid-uuid"];

    // -- Assert --
    XCTAssertNotNil(sentryId);
    XCTAssertEqualObjects(sentryId.sentryIdString, @"00000000000000000000000000000000");
}

- (void)testInit_whenCalledTwice_shouldReturnDifferentIds
{
    // -- Arrange & Act --
    SentryObjCId *id1 = [[SentryObjCId alloc] init];
    SentryObjCId *id2 = [[SentryObjCId alloc] init];

    // -- Assert --
    XCTAssertNotEqualObjects(id1.sentryIdString, id2.sentryIdString);
}

@end
