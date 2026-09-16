@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalSdkApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalSdkApiIntegrationTests

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

#pragma mark - Accessor

- (void)testInternal_sdk_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalSdkApi *sdk = SentryObjCSDK.internal.sdk;

    // -- Assert --
    XCTAssertNotNil(sdk);
}

#pragma mark - name

- (void)testName_shouldReturnDefaultSdkName
{
    // -- Act --
    NSString *name = SentryObjCSDK.internal.sdk.name;

    // -- Assert --
    XCTAssertEqualObjects(name, @"sentry.cocoa.objc");
}

- (void)testName_whenSet_shouldUpdateValue
{
    // -- Arrange --
    NSString *original = SentryObjCSDK.internal.sdk.name;

    // -- Act --
    SentryObjCSDK.internal.sdk.name = @"TestSDK";

    // -- Assert --
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.name, @"TestSDK");

    // -- Cleanup --
    SentryObjCSDK.internal.sdk.name = original;
}

#pragma mark - versionString

- (void)testVersionString_shouldReturnNonEmptyVersion
{
    // -- Act --
    NSString *version = SentryObjCSDK.internal.sdk.versionString;

    // -- Assert --
    XCTAssertTrue(
        [version containsString:@"."], @"Expected semver format with dots, got: %@", version);
}

#pragma mark - setName:version:

- (void)testSetNameVersion_shouldUpdateBoth
{
    // -- Arrange --
    NSString *originalName = SentryObjCSDK.internal.sdk.name;
    NSString *originalVersion = SentryObjCSDK.internal.sdk.versionString;

    // -- Act --
    [SentryObjCSDK.internal.sdk setName:@"NewSDK" version:@"9.9.9"];

    // -- Assert --
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.name, @"NewSDK");
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.versionString, @"9.9.9");

    // -- Cleanup --
    [SentryObjCSDK.internal.sdk setName:originalName version:originalVersion];
}

#pragma mark - addPackageName

- (void)testAddPackageName_whenAdded_shouldRetainPackageInfo
{
    // -- Act --
    [SentryObjCSDK.internal.sdk addPackageName:@"objc-test-pkg" version:@"2.0.0"];

    // -- Assert --
    // Verify the call doesn't crash and the name is still accessible
    XCTAssertEqualObjects(SentryObjCSDK.internal.sdk.name, @"sentry.cocoa.objc");
}

#pragma mark - installationID

- (void)testInstallationID_shouldReturnUUIDFormat
{
    // -- Act --
    NSString *installationID = SentryObjCSDK.internal.sdk.installationID;

    // -- Assert --
    XCTAssertEqual(installationID.length, 36u, @"Expected UUID format (36 chars with hyphens)");
}

#pragma mark - extraContext

- (void)testExtraContext_shouldContainDeviceKey
{
    // -- Act --
    NSDictionary *context = SentryObjCSDK.internal.sdk.extraContext;

    // -- Assert --
    XCTAssertNotNil(context[@"device"]);
}

@end
