@import SentryObjC;
@import XCTest;

@interface SentryObjCMechanismTests : XCTestCase
@end

@implementation SentryObjCMechanismTests

#pragma mark - SentryObjCMechanism

- (void)testInit_whenType_shouldSetType
{
    // -- Arrange & Act --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Assert --
    XCTAssertNotNil(mech);
    XCTAssertEqualObjects(mech.type, @"generic");
}

- (void)testType_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.type = @"nserror";

    // -- Assert --
    XCTAssertEqualObjects(mech.type, @"nserror");
}

- (void)testDesc_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    NSString *result = mech.desc;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testDesc_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.desc = @"An error occurred";

    // -- Assert --
    XCTAssertEqualObjects(mech.desc, @"An error occurred");
}

- (void)testDesc_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.desc = @"An error occurred";

    // -- Act --
    mech.desc = nil;

    // -- Assert --
    XCTAssertNil(mech.desc);
}

- (void)testData_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    NSDictionary *result = mech.data;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testData_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.data = @{ @"key" : @"value" };

    // -- Assert --
    XCTAssertEqualObjects(mech.data[@"key"], @"value");
}

- (void)testData_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.data = @{ @"key" : @"value" };

    // -- Act --
    mech.data = nil;

    // -- Assert --
    XCTAssertNil(mech.data);
}

- (void)testHandled_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    NSNumber *result = mech.handled;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testHandled_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.handled = @YES;

    // -- Assert --
    XCTAssertEqualObjects(mech.handled, @YES);
}

- (void)testHandled_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.handled = @YES;

    // -- Act --
    mech.handled = nil;

    // -- Assert --
    XCTAssertNil(mech.handled);
}

- (void)testSynthetic_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    NSNumber *result = mech.synthetic;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testSynthetic_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.synthetic = @NO;

    // -- Assert --
    XCTAssertEqualObjects(mech.synthetic, @NO);
}

- (void)testSynthetic_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.synthetic = @NO;

    // -- Act --
    mech.synthetic = nil;

    // -- Assert --
    XCTAssertNil(mech.synthetic);
}

- (void)testHelpLink_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    NSString *result = mech.helpLink;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testHelpLink_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    mech.helpLink = @"https://example.com/help";

    // -- Assert --
    XCTAssertEqualObjects(mech.helpLink, @"https://example.com/help");
}

- (void)testHelpLink_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.helpLink = @"https://example.com/help";

    // -- Act --
    mech.helpLink = nil;

    // -- Assert --
    XCTAssertNil(mech.helpLink);
}

- (void)testMeta_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    SentryObjCMechanismContext *result = mech.meta;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testMeta_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    mech.meta = ctx;

    // -- Assert --
    XCTAssertNotNil(mech.meta);
}

- (void)testMeta_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];
    mech.meta = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    mech.meta = nil;

    // -- Assert --
    XCTAssertNil(mech.meta);
}

#pragma mark - SentryObjCMechanismContext

- (void)testContextInit_shouldBeNotNil
{
    // -- Arrange & Act --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

- (void)testContextSignal_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    NSDictionary *result = ctx.signal;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testContextSignal_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    ctx.signal = @{ @"number" : @11, @"name" : @"SIGSEGV" };

    // -- Assert --
    XCTAssertEqualObjects(ctx.signal[@"name"], @"SIGSEGV");
}

- (void)testContextSignal_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];
    ctx.signal = @{ @"number" : @11, @"name" : @"SIGSEGV" };

    // -- Act --
    ctx.signal = nil;

    // -- Assert --
    XCTAssertNil(ctx.signal);
}

- (void)testContextMachException_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    NSDictionary *result = ctx.machException;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testContextMachException_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    ctx.machException = @{ @"exception" : @1, @"code" : @0, @"subcode" : @0 };

    // -- Assert --
    XCTAssertNotNil(ctx.machException);
}

- (void)testContextMachException_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];
    ctx.machException = @{ @"exception" : @1, @"code" : @0, @"subcode" : @0 };

    // -- Act --
    ctx.machException = nil;

    // -- Assert --
    XCTAssertNil(ctx.machException);
}

- (void)testContextError_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];

    // -- Act --
    SentryObjCNSError *result = ctx.error;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testContextError_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];
    SentryObjCNSError *nsError = [[SentryObjCNSError alloc] initWithDomain:@"TestDomain" code:42];

    // -- Act --
    ctx.error = nsError;

    // -- Assert --
    XCTAssertNotNil(ctx.error);
}

- (void)testContextError_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMechanismContext *ctx = [[SentryObjCMechanismContext alloc] init];
    ctx.error = [[SentryObjCNSError alloc] initWithDomain:@"TestDomain" code:42];

    // -- Act --
    ctx.error = nil;

    // -- Assert --
    XCTAssertNil(ctx.error);
}

@end
