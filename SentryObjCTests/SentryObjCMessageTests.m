@import SentryObjC;
@import XCTest;

@interface SentryObjCMessageTests : XCTestCase
@end

@implementation SentryObjCMessageTests

- (void)testInit_whenFormatted_shouldSetFormatted
{
    // -- Arrange & Act --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];

    // -- Assert --
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.formatted, @"Hello %s");
}

- (void)testMessage_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];

    // -- Act --
    NSString *result = message.message;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testMessage_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];

    // -- Act --
    message.message = @"Hello %s";

    // -- Assert --
    XCTAssertEqualObjects(message.message, @"Hello %s");
}

- (void)testMessage_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];
    message.message = @"Hello %s";

    // -- Act --
    message.message = nil;

    // -- Assert --
    XCTAssertNil(message.message);
}

- (void)testParams_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];

    // -- Act --
    NSArray *result = message.params;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testParams_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];

    // -- Act --
    message.params = @[ @"world" ];

    // -- Assert --
    XCTAssertEqualObjects(message.params, (@[ @"world" ]));
}

- (void)testParams_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMessage *message = [[SentryObjCMessage alloc] initWithFormatted:@"Hello %s"];
    message.params = @[ @"world" ];

    // -- Act --
    message.params = nil;

    // -- Assert --
    XCTAssertNil(message.params);
}

@end
