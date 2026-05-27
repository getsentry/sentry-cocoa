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

- (void)testGetSdkName_shouldReturnString
{
    // -- Act --
    NSString *name = [SentryObjCPrivateSDKOnly getSdkName];

    // -- Assert --
    XCTAssertNotNil(name);
    XCTAssertTrue(name.length > 0);
}

- (void)testGetSdkVersionString_shouldReturnString
{
    // -- Act --
    NSString *version = [SentryObjCPrivateSDKOnly getSdkVersionString];

    // -- Assert --
    XCTAssertNotNil(version);
    XCTAssertTrue(version.length > 0);
}

- (void)testSetSdkNameAndVersion_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly setSdkName:@"test.sdk" andVersionString:@"1.0.0"];
}

- (void)testSetSdkName_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly setSdkName:@"test.sdk"];
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

- (void)testInstallationID_shouldReturnString
{
    // -- Act --
    NSString *installationID = SentryObjCPrivateSDKOnly.installationID;

    // -- Assert --
    XCTAssertNotNil(installationID);
    XCTAssertTrue(installationID.length > 0);
}

#pragma mark - App start measurement

- (void)testAppStartMeasurementHybridSDKMode_whenSet_shouldReturnValue
{
    // -- Act --
    SentryObjCPrivateSDKOnly.appStartMeasurementHybridSDKMode = YES;

    // -- Assert --
    XCTAssertTrue(SentryObjCPrivateSDKOnly.appStartMeasurementHybridSDKMode);
}

#pragma mark - User and breadcrumb from dictionary

- (void)testUserWithDictionary_shouldReturnUser
{
    // -- Act --
    SentryObjCUser *user = [SentryObjCPrivateSDKOnly userWithDictionary:@{ @"id" : @"u1" }];

    // -- Assert --
    XCTAssertNotNil(user);
}

- (void)testBreadcrumbWithDictionary_shouldReturnBreadcrumb
{
    // -- Act --
    SentryObjCBreadcrumb *crumb =
        [SentryObjCPrivateSDKOnly breadcrumbWithDictionary:@{ @"category" : @"test" }];

    // -- Assert --
    XCTAssertNotNil(crumb);
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

    // -- Act & Assert (no crash) --
    [SentryObjCPrivateSDKOnly captureEnvelope:envelope];
}

@end
