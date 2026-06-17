@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_HAS_UIKIT && !TARGET_OS_VISION

@interface SentryObjCInternalScreenshotApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalScreenshotApiIntegrationTests

- (void)setUp
{
    [super setUp];
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

- (void)testInternal_screenshot_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalScreenshotApi *screenshot = SentryObjCSDK.internal.screenshot;

    // -- Assert --
    XCTAssertNotNil(screenshot);
}

#    pragma mark - capture

- (void)testCapture_whenNoWindows_shouldReturnEmptyArray
{
    // -- Act --
    NSArray<NSData *> *result = [SentryObjCSDK.internal.screenshot capture];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 0U);
}

@end

#endif
