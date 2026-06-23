@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_REPLAY_SUPPORTED

@interface SentryObjCInternalReplayApiTests : XCTestCase
@end

@implementation SentryObjCInternalReplayApiTests

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

#    pragma mark - capture

- (void)testCapture_withoutReplay_shouldReturnNO
{
    // -- Act --
    BOOL result = [SentryObjCSDK.internal.replay capture];

    // -- Assert --
    XCTAssertFalse(result);
}

#    pragma mark - replayId

- (void)testReplayId_withoutReplay_shouldReturnNil
{
    // -- Act --
    NSString *replayId = SentryObjCSDK.internal.replay.replayId;

    // -- Assert --
    XCTAssertNil(replayId);
}

#    pragma mark - addIgnoreClasses

- (void)testAddIgnoreClasses_withoutReplay_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay addIgnoreClasses:@[ [UILabel class] ]];
}

#    pragma mark - addRedactClasses

- (void)testAddRedactClasses_withoutReplay_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay addRedactClasses:@[ [UILabel class] ]];
}

#    pragma mark - setIgnoreContainerClass

- (void)testSetIgnoreContainerClass_withoutReplay_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setIgnoreContainerClass:[UIView class]];
}

#    pragma mark - setRedactContainerClass

- (void)testSetRedactContainerClass_withoutReplay_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setRedactContainerClass:[UIView class]];
}

#    pragma mark - setTags

- (void)testSetTags_withoutReplay_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.replay setTags:@{ @"key" : @"value" }];
}

@end

#endif
