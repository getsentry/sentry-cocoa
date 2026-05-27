@import SentryObjC;
@import XCTest;

@interface SentryObjCPrivateSDKOnlyTests : XCTestCase
@end

@implementation SentryObjCPrivateSDKOnlyTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - SDK name and version

- (void)testGetSdkName_shouldContainSentry
{
    // -- Act --
    NSString *name = [SentryObjCPrivateSDKOnly getSdkName];

    // -- Assert --
    XCTAssertNotNil(name);
    XCTAssertTrue(name.length > 0);
    XCTAssertTrue(
        [name containsString:@"sentry"], @"SDK name should contain 'sentry', got: %@", name);
}

- (void)testGetSdkVersionString_shouldReturnSemverLikeString
{
    // -- Act --
    NSString *version = [SentryObjCPrivateSDKOnly getSdkVersionString];

    // -- Assert --
    XCTAssertNotNil(version);
    XCTAssertTrue(version.length > 0);
    XCTAssertTrue([version containsString:@"."],
        @"SDK version should contain a dot for semver, got: %@", version);
}

- (void)testSetSdkNameAndVersion_shouldPersistRoundTrip
{
    // -- Arrange --
    NSString *originalName = [SentryObjCPrivateSDKOnly getSdkName];
    NSString *originalVersion = [SentryObjCPrivateSDKOnly getSdkVersionString];

    // -- Act --
    [SentryObjCPrivateSDKOnly setSdkName:@"test.sdk" andVersionString:@"1.0.0"];

    // -- Assert --
    XCTAssertEqualObjects([SentryObjCPrivateSDKOnly getSdkName], @"test.sdk");
    XCTAssertEqualObjects([SentryObjCPrivateSDKOnly getSdkVersionString], @"1.0.0");

    // -- Cleanup --
    [SentryObjCPrivateSDKOnly setSdkName:originalName andVersionString:originalVersion];
}

- (void)testSetSdkName_shouldPreserveVersion
{
    // -- Arrange --
    NSString *originalName = [SentryObjCPrivateSDKOnly getSdkName];
    NSString *originalVersion = [SentryObjCPrivateSDKOnly getSdkVersionString];

    // -- Act --
    [SentryObjCPrivateSDKOnly setSdkName:@"test.sdk"];

    // -- Assert --
    XCTAssertEqualObjects([SentryObjCPrivateSDKOnly getSdkName], @"test.sdk");
    XCTAssertEqualObjects([SentryObjCPrivateSDKOnly getSdkVersionString], originalVersion,
        @"Version should be preserved when only setting the name");

    // -- Cleanup --
    [SentryObjCPrivateSDKOnly setSdkName:originalName];
}

#pragma mark - SDK packages

- (void)testAddSdkPackage_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly addSdkPackage:@"test-package" version:@"1.0"];
}

#pragma mark - Extra context

- (void)testGetExtraContext_shouldReturnDictionary
{
    // -- Act --
    NSDictionary *ctx = [SentryObjCPrivateSDKOnly getExtraContext];

    // -- Assert --
    XCTAssertNotNil(ctx);
}

#pragma mark - Trace

- (void)testSetTrace_shouldNotCrash
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly setTrace:traceId spanId:spanId];
}

#pragma mark - Installation ID

- (void)testInstallationID_shouldReturnConsistentValue
{
    // -- Act --
    NSString *first = SentryObjCPrivateSDKOnly.installationID;
    NSString *second = SentryObjCPrivateSDKOnly.installationID;

    // -- Assert --
    XCTAssertNotNil(first);
    XCTAssertTrue(first.length > 0);
    XCTAssertEqualObjects(first, second, @"Installation ID should be consistent across calls");
}

#pragma mark - App start measurement

- (void)testAppStartMeasurementHybridSDKMode_initialValueIsFalse
{
    // -- Assert --
    XCTAssertFalse(
        SentryObjCPrivateSDKOnly.appStartMeasurementHybridSDKMode, @"Initial value should be NO");
}

- (void)testAppStartMeasurementHybridSDKMode_whenSet_shouldReturnValue
{
    // -- Act --
    SentryObjCPrivateSDKOnly.appStartMeasurementHybridSDKMode = YES;

    // -- Assert --
    XCTAssertTrue(SentryObjCPrivateSDKOnly.appStartMeasurementHybridSDKMode);
}

#pragma mark - User and breadcrumb from dictionary

- (void)testUserWithDictionary_shouldReturnUserWithMatchingId
{
    // -- Act --
    SentryObjCUser *user = [SentryObjCPrivateSDKOnly userWithDictionary:@{ @"id" : @"u1" }];

    // -- Assert --
    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.userId, @"u1");
}

- (void)testBreadcrumbWithDictionary_shouldReturnBreadcrumbWithMatchingCategory
{
    // -- Act --
    SentryObjCBreadcrumb *crumb =
        [SentryObjCPrivateSDKOnly breadcrumbWithDictionary:@{ @"category" : @"test" }];

    // -- Assert --
    XCTAssertNotNil(crumb);
    XCTAssertEqualObjects(crumb.category, @"test");
}

#pragma mark - Log output

- (void)testSetLogOutput_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly setLogOutput:^(NSString *msg) { (void)msg; }];
}

#pragma mark - Signal handling

- (void)testIgnoreNextSignal_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly ignoreNextSignal:0];
}

#pragma mark - Envelope

- (void)testEnvelopeWithData_whenInvalidData_shouldReturnNil
{
    // -- Arrange --
    NSData *emptyData = [[NSData alloc] init];

    // -- Act --
    SentryObjCEnvelope *envelope = [SentryObjCPrivateSDKOnly envelopeWithData:emptyData];

    // -- Assert --
    XCTAssertNil(envelope);
}

- (void)testEnvelopeWithData_whenValidData_shouldParseEnvelope
{
    // -- Arrange --
    NSString *rawData = @"{}\n{\"length\":0,\"type\":\"attachment\"}\n";
    NSData *data = [rawData dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelope *envelope = [SentryObjCPrivateSDKOnly envelopeWithData:data];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertNotNil(envelope.header);
    XCTAssertEqual(envelope.items.count, 1U);
    XCTAssertEqualObjects(envelope.items.firstObject.type, @"attachment");
}

- (void)testStoreEnvelope_shouldNotCrash
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"event"
                                                                           data:data
                                                                    addPlatform:NO];
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // -- Assert (envelope structure) --
    XCTAssertNotNil(envelope.header);
    XCTAssertEqual(envelope.items.count, 1U);

    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly storeEnvelope:envelope];
}

- (void)testCaptureEnvelope_shouldNotCrash
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"event"
                                                                           data:data
                                                                    addPlatform:NO];
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // -- Assert (envelope structure) --
    XCTAssertNotNil(envelope.header);
    XCTAssertEqual(envelope.items.count, 1U);

    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly captureEnvelope:envelope];
}

@end
