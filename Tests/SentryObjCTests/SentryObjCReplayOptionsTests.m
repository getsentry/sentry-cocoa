@import SentryObjC;
@import XCTest;

@interface SentryObjCReplayOptionsTests : XCTestCase
@end

@implementation SentryObjCReplayOptionsTests

#pragma mark - Float properties

- (void)testSessionSampleRate_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.sessionSampleRate = 0.5f;

    // -- Assert --
    XCTAssertEqualWithAccuracy(options.sessionSampleRate, 0.5f, 0.001f);
}

- (void)testOnErrorSampleRate_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.onErrorSampleRate = 0.75f;

    // -- Assert --
    XCTAssertEqualWithAccuracy(options.onErrorSampleRate, 0.75f, 0.001f);
}

#pragma mark - Bool properties

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testMaskAllText_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    options.maskAllText = YES;

    // -- Assert --
    XCTAssertTrue(options.maskAllText);
}
#endif

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testMaskAllImages_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    options.maskAllImages = YES;

    // -- Assert --
    XCTAssertTrue(options.maskAllImages);
}
#endif

- (void)testEnableViewRendererV2_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.enableViewRendererV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableViewRendererV2);
}

- (void)testEnableFastViewRendering_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.enableFastViewRendering = YES;

    // -- Assert --
    XCTAssertTrue(options.enableFastViewRendering);
}

- (void)testNetworkCaptureBodies_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.networkCaptureBodies = YES;

    // -- Assert --
    XCTAssertTrue(options.networkCaptureBodies);
}

#pragma mark - Enum property

- (void)testQuality_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.quality = SentryObjCReplayQualityHigh;

    // -- Assert --
    XCTAssertEqual(options.quality, SentryObjCReplayQualityHigh);
}

#pragma mark - Collection properties

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testMaskedViewClasses_whenSet_shouldReturnCorrectCount
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    options.maskedViewClasses = @[ [NSObject class] ];

    // -- Assert --
    XCTAssertEqual(options.maskedViewClasses.count, 1u);
}
#endif

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testUnmaskedViewClasses_whenSet_shouldReturnCorrectCount
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    options.unmaskedViewClasses = @[ [NSString class] ];

    // -- Assert --
    XCTAssertEqual(options.unmaskedViewClasses.count, 1u);
}
#endif

- (void)testNetworkRequestHeaders_whenSet_shouldContainCustomValue
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.networkRequestHeaders = @[ @"X-Custom" ];

    // -- Assert (merges with defaults) --
    XCTAssertTrue([options.networkRequestHeaders containsObject:@"X-Custom"]);
}

- (void)testNetworkResponseHeaders_whenSet_shouldContainCustomValue
{
    // -- Arrange --
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];

    // -- Act --
    options.networkResponseHeaders = @[ @"X-Response" ];

    // -- Assert (merges with defaults) --
    XCTAssertTrue([options.networkResponseHeaders containsObject:@"X-Response"]);
}

#pragma mark - Methods (no-crash tests)

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testExcludeViewTypeFromSubtreeTraversal_whenCalled_shouldNotCrash
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    [options excludeViewTypeFromSubtreeTraversal:@"SomeView"];

    // -- Assert --
    // No crash means success
}
#endif

#if !SDK_V10 || ((TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT)
- (void)testIncludeViewTypeInSubtreeTraversal_whenCalled_shouldNotCrash
{
    // -- Arrange --
#    if SDK_V10
    SentryObjCPrivacyOptions *options = [[SentryObjCPrivacyOptions alloc] init];
#    else
    SentryObjCReplayOptions *options = [[SentryObjCReplayOptions alloc] init];
#    endif // SDK_V10

    // -- Act --
    [options includeViewTypeInSubtreeTraversal:@"SomeView"];

    // -- Assert --
    // No crash means success
}
#endif

#if SDK_V10 && (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT
- (void)testPrivacy_whenConfiguredThroughOptions_shouldUpdateSharedSettings
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.privacy.maskAllText = NO;
    [options.privacy excludeViewTypeFromSubtreeTraversal:@"CustomView"];

    // -- Assert --
    XCTAssertFalse(options.privacy.maskAllText);
    XCTAssertTrue([options.privacy.excludedViewClasses containsObject:@"CustomView"]);
    XCTAssertTrue(options.privacy.maskAllImages);
}
#endif

@end
