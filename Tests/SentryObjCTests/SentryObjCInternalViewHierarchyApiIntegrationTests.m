@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_HAS_UIKIT && !TARGET_OS_VISION

@interface SentryObjCInternalViewHierarchyApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalViewHierarchyApiIntegrationTests

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

- (void)testInternal_viewHierarchy_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalViewHierarchyApi *viewHierarchy = SentryObjCSDK.internal.viewHierarchy;

    // -- Assert --
    XCTAssertNotNil(viewHierarchy);
}

#    pragma mark - capture

- (void)testCapture_whenNoWindows_shouldReturnValidJSON
{
    // -- Act --
    NSData *result = [SentryObjCSDK.internal.viewHierarchy capture];

    // -- Assert --
    XCTAssertNotNil(result);
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:result options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(json[@"rendering_system"], @"UIKIT");
    NSArray *windows = json[@"windows"];
    XCTAssertNotNil(windows);
    XCTAssertEqual(windows.count, 0U);
}

@end

#endif
