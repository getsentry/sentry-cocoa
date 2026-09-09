@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_HAS_UIKIT

@interface SentryObjCInternalPerformanceApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalPerformanceApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.enableAutoPerformanceTracing = NO;
#    if !SDK_V10
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.enableAppHangTracking = NO;
#        pragma clang diagnostic pop
#    endif // !SDK_V10
        options.enableWatchdogTerminationTracking = NO;
        options.enableSwizzling = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#    pragma mark - Accessor

- (void)testInternal_performance_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalPerformanceApi *performance = SentryObjCSDK.internal.performance;

    // -- Assert --
    XCTAssertNotNil(performance);
}

#    pragma mark - framesTrackingHybridSDKMode

- (void)testFramesTrackingHybridSDKMode_defaultIsFalse
{
    // -- Assert --
    XCTAssertFalse(SentryObjCSDK.internal.performance.framesTrackingHybridSDKMode);
}

- (void)testFramesTrackingHybridSDKMode_whenSet_shouldUpdateValue
{
    // -- Act --
    SentryObjCSDK.internal.performance.framesTrackingHybridSDKMode = YES;

    // -- Assert --
    XCTAssertTrue(SentryObjCSDK.internal.performance.framesTrackingHybridSDKMode);

    // -- Cleanup --
    SentryObjCSDK.internal.performance.framesTrackingHybridSDKMode = NO;
}

#    pragma mark - isFramesTrackingRunning

- (void)testIsFramesTrackingRunning_defaultIsFalse
{
    // -- Assert --
    XCTAssertFalse(SentryObjCSDK.internal.performance.isFramesTrackingRunning);
}

@end

#endif
