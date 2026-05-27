@import SentryObjC;
@import XCTest;

#import <TargetConditionals.h>

@interface SentryObjCSDKTests : XCTestCase
@end

@implementation SentryObjCSDKTests

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

#pragma mark - Start / State

- (void)testStartWithOptions_shouldNotCrash
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.dsn = @"https://key@sentry.io/123";
    options.enableCrashHandler = NO;

    // -- Act & Assert (no crash) --
    [SentryObjCSDK startWithOptions:options];
}

- (void)testIsEnabled_whenStarted_shouldReturnTrue
{
    // -- Arrange & Act --
    BOOL enabled = SentryObjCSDK.isEnabled;

    // -- Assert --
    XCTAssertTrue(enabled);
}

- (void)testSpan_whenNoTransaction_shouldReturnNil
{
    // -- Arrange & Act --
    SentryObjCSpan *span = SentryObjCSDK.span;

    // -- Assert --
    XCTAssertNil(span);
}

- (void)testLogger_shouldReturnLogger
{
    // -- Arrange & Act --
    SentryObjCLogger *logger = SentryObjCSDK.logger;

    // -- Assert --
    XCTAssertNotNil(logger);
}

#pragma mark - Capture Event

- (void)testCaptureEvent_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureEventWithScope_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureEventWithScopeBlock_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event
                                        withScopeBlock:^(SentryObjCScope *scope) { }];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureEventAttachAllThreads_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
}

#pragma mark - Transactions

- (void)testStartTransaction_shouldReturnSpan
{
    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithName:@"test" operation:@"op"];

    // -- Assert --
    XCTAssertNotNil(span);
}

- (void)testStartTransactionBindToScope_shouldReturnSpan
{
    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithName:@"test"
                                                         operation:@"op"
                                                       bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
}

- (void)testStartTransactionWithContext_shouldReturnSpan
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx];

    // -- Assert --
    XCTAssertNotNil(span);
}

- (void)testStartTransactionWithContextBindToScope_shouldReturnSpan
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
}

- (void)testStartTransactionWithContextBindToScopeCustomSampling_shouldReturnSpan
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];
    NSDictionary<NSString *, id> *customSamplingContext = @{ @"key" : @"value" };

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx
                                                          bindToScope:YES
                                                customSamplingContext:customSamplingContext];

    // -- Assert --
    XCTAssertNotNil(span);
}

- (void)testStartTransactionWithContextCustomSampling_shouldReturnSpan
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];
    NSDictionary<NSString *, id> *customSamplingContext = @{ @"key" : @"value" };

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx
                                                customSamplingContext:customSamplingContext];

    // -- Assert --
    XCTAssertNotNil(span);
}

#pragma mark - Capture Error

- (void)testCaptureError_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureErrorWithScope_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureErrorWithScopeBlock_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error
                                        withScopeBlock:^(SentryObjCScope *scope) { }];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureErrorAttachAllThreads_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
}

#pragma mark - Capture Exception

- (void)testCaptureException_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureExceptionWithScope_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureExceptionWithScopeBlock_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception
                                            withScopeBlock:^(SentryObjCScope *scope) { }];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureExceptionAttachAllThreads_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
}

#pragma mark - Capture Message

- (void)testCaptureMessage_shouldReturnId
{
    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello"];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureMessageWithScope_shouldReturnId
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello" withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureMessageWithScopeBlock_shouldReturnId
{
    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello"
                                          withScopeBlock:^(SentryObjCScope *scope) { }];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureMessageAttachAllThreads_shouldReturnId
{
    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello" attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
}

#pragma mark - Feedback

- (void)testCaptureFeedback_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK captureFeedbackWithMessage:@"test"
                                         name:nil
                                        email:nil
                                       source:SentryObjCFeedbackSourceCustom
                            associatedEventId:nil
                                  attachments:nil];
}

#pragma mark - Breadcrumbs

- (void)testAddBreadcrumb_shouldNotCrash
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act & Assert (no crash) --
    [SentryObjCSDK addBreadcrumb:crumb];
}

#pragma mark - Configure Scope

- (void)testConfigureScope_shouldCallBlock
{
    // -- Arrange --
    __block BOOL called = NO;

    // -- Act --
    [SentryObjCSDK configureScope:^(SentryObjCScope *scope) { called = YES; }];

    // -- Assert --
    XCTAssertTrue(called);
}

#pragma mark - Crash Status

- (void)testCrashedLastRun_shouldReturnBool
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Arrange & Act --
    BOOL crashed = SentryObjCSDK.crashedLastRun;

    // -- Assert --
    XCTAssertTrue(crashed || !crashed);
#pragma clang diagnostic pop
}

- (void)testLastRunStatus_shouldReturnStatus
{
    // -- Arrange & Act --
    SentryObjCLastRunStatus status = SentryObjCSDK.lastRunStatus;

    // -- Assert --
    // Just verify property access doesn't crash; value depends on runtime state.
    XCTAssertTrue(status == SentryObjCLastRunStatusUnknown
        || status == SentryObjCLastRunStatusDidCrash
        || status == SentryObjCLastRunStatusDidNotCrash);
}

- (void)testDetectedStartUpCrash_shouldReturnBool
{
    // -- Arrange & Act --
    BOOL detected = SentryObjCSDK.detectedStartUpCrash;

    // -- Assert --
    XCTAssertTrue(detected || !detected);
}

#pragma mark - User

- (void)testSetUser_shouldNotCrash
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] initWithUserId:@"u1"];

    // -- Act & Assert (no crash) --
    [SentryObjCSDK setUser:user];
}

- (void)testSetUserNil_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK setUser:nil];
}

#pragma mark - Sessions

- (void)testStartSession_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK startSession];
}

- (void)testEndSession_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK endSession];
}

#pragma mark - Display / App Hang

- (void)testReportFullyDisplayed_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK reportFullyDisplayed];
}

- (void)testPauseAppHangTracking_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK pauseAppHangTracking];
}

- (void)testResumeAppHangTracking_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK resumeAppHangTracking];
}

#pragma mark - Flush

- (void)testFlush_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK flush:0.1];
}

#pragma mark - Platform-Conditional

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)testReplay_shouldReturnReplayApi
{
    // -- Arrange & Act --
    SentryObjCReplayApi *replayApi = SentryObjCSDK.replay;

    // -- Assert --
    XCTAssertNotNil(replayApi);
}
#endif

#if TARGET_OS_IOS
- (void)testFeedback_shouldReturnFeedbackApi
{
    // -- Arrange & Act --
    SentryObjCFeedbackApi *feedbackApi = SentryObjCSDK.feedback;

    // -- Assert --
    XCTAssertNotNil(feedbackApi);
}
#endif

@end
