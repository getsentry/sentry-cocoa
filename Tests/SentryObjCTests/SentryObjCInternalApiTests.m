@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalApiTests : XCTestCase
@end

@implementation SentryObjCInternalApiTests

- (void)setUp
{
    [super setUp];

#if TARGET_OS_VISION && TARGET_OS_SIMULATOR
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 27) {
        XCTSkip(@"Full SDK start is too slow on visionOS 27 simulator");
        return;
    }
#endif

    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    SentryObjCSDK.internal.appStart.hybridSDKMode = NO;
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - SDK name and version

- (void)testGetSdkName_shouldContainSentry
{
    // -- Act --
    NSString *name = SentryObjCSDK.internal.sdk.name;

    // -- Assert --
    XCTAssertNotNil(name);
    XCTAssertTrue(name.length > 0);
    XCTAssertTrue(
        [name containsString:@"sentry"], @"SDK name should contain 'sentry', got: %@", name);
}

- (void)testGetSdkVersionString_shouldReturnSemverLikeString
{
    // -- Act --
    NSString *version = SentryObjCSDK.internal.sdk.versionString;

    // -- Assert --
    XCTAssertNotNil(version);
    XCTAssertTrue(version.length > 0);
    XCTAssertTrue([version containsString:@"."],
        @"SDK version should contain a dot for semver, got: %@", version);
}

- (void)testSetSdkNameAndVersion_shouldPersistRoundTrip
{
    // -- Arrange --
    NSString *originalName = SentryObjCSDK.internal.sdk.name;
    NSString *originalVersion = SentryObjCSDK.internal.sdk.versionString;

    // -- Act --
    [SentryObjCSDK.internal.sdk setName:@"test.sdk" version:@"1.0.0"];

    // -- Assert --
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.name, @"test.sdk");
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.versionString, @"1.0.0");

    // -- Cleanup --
    [SentryObjCSDK.internal.sdk setName:originalName version:originalVersion];
}

- (void)testSetSdkName_shouldPreserveVersion
{
    // -- Arrange --
    NSString *originalName = SentryObjCSDK.internal.sdk.name;
    NSString *originalVersion = SentryObjCSDK.internal.sdk.versionString;

    // -- Act --
    SentryObjCSDK.internal.sdk.name = @"test.sdk";

    // -- Assert --
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.name, @"test.sdk");
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.versionString, originalVersion,
        @"Version should be preserved when only setting the name");

    // -- Cleanup --
    SentryObjCSDK.internal.sdk.name = originalName;
}

#pragma mark - SDK packages

- (void)testAddSdkPackage_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.sdk addPackageName:@"test-package" version:@"1.0"];
}

#pragma mark - Extra context

- (void)testGetExtraContext_shouldReturnDictionary
{
    // -- Act --
    NSDictionary *ctx = SentryObjCSDK.internal.sdk.extraContext;

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
    [SentryObjCSDK.internal setTrace:traceId spanId:spanId];
}

#pragma mark - Installation ID

- (void)testInstallationID_shouldReturnConsistentValue
{
    // -- Act --
    NSString *first = SentryObjCSDK.internal.sdk.installationID;
    NSString *second = SentryObjCSDK.internal.sdk.installationID;

    // -- Assert --
    XCTAssertNotNil(first);
    XCTAssertTrue(first.length > 0);
    XCTAssertEqualObjects(first, second, @"Installation ID should be consistent across calls");
}

#pragma mark - App start measurement

- (void)testAppStartMeasurementHybridSDKMode_initialValueIsFalse
{
    // -- Assert --
    XCTAssertFalse(SentryObjCSDK.internal.appStart.hybridSDKMode, @"Initial value should be NO");
}

- (void)testAppStartMeasurementHybridSDKMode_whenSet_shouldReturnValue
{
    // -- Act --
    SentryObjCSDK.internal.appStart.hybridSDKMode = YES;

    // -- Assert --
    XCTAssertTrue(SentryObjCSDK.internal.appStart.hybridSDKMode);
}

#pragma mark - User and breadcrumb from dictionary

- (void)testUserWithDictionary_shouldReturnUserWithMatchingId
{
    // -- Act --
    SentryObjCUser *user = [SentryObjCSDK.internal.user fromDictionary:@{ @"id" : @"u1" }];

    // -- Assert --
    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.userId, @"u1");
}

- (void)testBreadcrumbWithDictionary_shouldReturnBreadcrumbWithMatchingCategory
{
    // -- Act --
    SentryObjCBreadcrumb *crumb =
        [SentryObjCSDK.internal.breadcrumbs fromDictionary:@{ @"category" : @"test" }];

    // -- Assert --
    XCTAssertNotNil(crumb);
    XCTAssertEqualObjects(crumb.category, @"test");
}

#pragma mark - Log output

- (void)testSetLogOutput_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal setLogOutput:^(NSString *msg) { (void)msg; }];
}

#pragma mark - Signal handling

- (void)testIgnoreNextSignal_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal ignoreNextSignal:0];
}

#pragma mark - Envelope

- (void)testEnvelopeWithData_whenInvalidData_shouldReturnNil
{
    // -- Arrange --
    NSData *emptyData = [[NSData alloc] init];

    // -- Act --
    SentryObjCEnvelope *envelope = [SentryObjCSDK.internal.envelope deserializeFrom:emptyData];

    // -- Assert --
    XCTAssertNil(envelope);
}

- (void)testEnvelopeWithData_whenValidData_shouldParseEnvelope
{
    // -- Arrange --
    NSString *rawData = @"{}\n{\"length\":0,\"type\":\"attachment\"}\n";
    NSData *data = [rawData dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelope *envelope = [SentryObjCSDK.internal.envelope deserializeFrom:data];

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
    [SentryObjCSDK.internal.envelope store:envelope];
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
    [SentryObjCSDK.internal.envelope capture:envelope];
}

@end
