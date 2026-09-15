@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_HAS_UIKIT

@interface SentryObjCInternalScreenApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalScreenApiIntegrationTests

- (void)setUp
{
    [super setUp];

#    if TARGET_OS_VISION && TARGET_OS_SIMULATOR
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 27) {
        XCTSkip(@"Full SDK start is too slow on visionOS 27 simulator");
        return;
    }
#    endif

    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.enableAutoPerformanceTracing = NO;
        options.enableSwizzling = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#    pragma mark - Accessor

- (void)testInternal_screen_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalScreenApi *screen = SentryObjCSDK.internal.screen;

    // -- Assert --
    XCTAssertNotNil(screen);
}

#    pragma mark - setCurrent

- (void)testSetCurrent_withScreenName_shouldNotThrow
{
    // -- Act / Assert --
    XCTAssertNoThrow([SentryObjCSDK.internal.screen setCurrent:@"TestScreen"]);
}

- (void)testSetCurrent_withNil_shouldNotThrow
{
    // -- Act / Assert --
    XCTAssertNoThrow([SentryObjCSDK.internal.screen setCurrent:nil]);
}

@end

#endif
