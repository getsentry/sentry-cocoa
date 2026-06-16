@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalSwizzleApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalSwizzleApiIntegrationTests

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

- (void)testInternal_swizzle_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalSwizzleApi *swizzle = SentryObjCSDK.internal.swizzle;

    // -- Assert --
    XCTAssertNotNil(swizzle);
}

@end
