@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalAppStartApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalAppStartApiIntegrationTests

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
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - Accessor

- (void)testInternal_appStart_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalAppStartApi *appStart = SentryObjCSDK.internal.appStart;

    // -- Assert --
    XCTAssertNotNil(appStart);
}

#pragma mark - hybridSDKMode

- (void)testHybridSDKMode_defaultIsFalse
{
    // -- Assert --
    XCTAssertFalse(SentryObjCSDK.internal.appStart.hybridSDKMode);
}

- (void)testHybridSDKMode_whenSet_shouldUpdateValue
{
    // -- Act --
    SentryObjCSDK.internal.appStart.hybridSDKMode = YES;

    // -- Assert --
    XCTAssertTrue(SentryObjCSDK.internal.appStart.hybridSDKMode);

    // -- Cleanup --
    SentryObjCSDK.internal.appStart.hybridSDKMode = NO;
}

#pragma mark - measurementWithSpans

- (void)testMeasurementWithSpans_withoutAppStart_shouldReturnNil
{
    // -- Act --
    NSDictionary<NSString *, id> *result = SentryObjCSDK.internal.appStart.measurementWithSpans;

    // -- Assert --
    XCTAssertNil(result);
}

@end
