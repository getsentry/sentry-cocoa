@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalBreadcrumbApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalBreadcrumbApiIntegrationTests

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

- (void)testInternal_breadcrumbs_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalBreadcrumbApi *breadcrumbs = SentryObjCSDK.internal.breadcrumbs;

    // -- Assert --
    XCTAssertNotNil(breadcrumbs);
}

#pragma mark - fromDictionary

- (void)testFromDictionary_whenPopulated_shouldMapFields
{
    // -- Arrange --
    NSDictionary *dict = @{
        @"message" : @"test breadcrumb",
        @"category" : @"navigation",
        @"level" : @"info",
        @"type" : @"default"
    };

    // -- Act --
    SentryObjCBreadcrumb *breadcrumb = [SentryObjCSDK.internal.breadcrumbs fromDictionary:dict];

    // -- Assert --
    XCTAssertEqualObjects(breadcrumb.message, @"test breadcrumb");
    XCTAssertEqualObjects(breadcrumb.category, @"navigation");
    XCTAssertEqualObjects(breadcrumb.type, @"default");
}

- (void)testFromDictionary_whenEmpty_shouldReturnBreadcrumb
{
    // -- Act --
    SentryObjCBreadcrumb *breadcrumb = [SentryObjCSDK.internal.breadcrumbs fromDictionary:@{ }];

    // -- Assert --
    XCTAssertNotNil(breadcrumb);
}

@end
