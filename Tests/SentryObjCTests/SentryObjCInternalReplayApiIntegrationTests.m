@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_REPLAY_SUPPORTED

@interface SentryObjCInternalReplayApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalReplayApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        SentryObjCReplayOptions *replayOptions = [[SentryObjCReplayOptions alloc] init];
        replayOptions.sessionSampleRate = 1.0;
        replayOptions.onErrorSampleRate = 1.0;
        options.sessionReplay = replayOptions;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#    pragma mark - Accessor

- (void)testInternal_replay_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalReplayApi *replay = SentryObjCSDK.internal.replay;

    // -- Assert --
    XCTAssertNotNil(replay);
}

#    pragma mark - capture

- (void)testCapture_withReplayEnabled_shouldNotCrash
{
    // -- Act --
    BOOL result = [SentryObjCSDK.internal.replay capture];

    // -- Assert (capture may return YES or NO depending on integration state) --
    (void)result;
}

#    pragma mark - replayId

- (void)testReplayId_shouldReturnNilOrString
{
    // -- Act --
    NSString *replayId = SentryObjCSDK.internal.replay.replayId;

    // -- Assert (nil when no replay is actively recording) --
    (void)replayId;
}

#    pragma mark - addIgnoreClasses

- (void)testAddIgnoreClasses_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay addIgnoreClasses:@[ [UILabel class] ]];
}

#    pragma mark - addRedactClasses

- (void)testAddRedactClasses_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay addRedactClasses:@[ [UILabel class] ]];
}

#    pragma mark - setIgnoreContainerClass

- (void)testSetIgnoreContainerClass_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setIgnoreContainerClass:[UIView class]];
}

#    pragma mark - setRedactContainerClass

- (void)testSetRedactContainerClass_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setRedactContainerClass:[UIView class]];
}

#    pragma mark - setTags

- (void)testSetTags_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setTags:@{ @"environment" : @"test" }];
}

@end

#endif
