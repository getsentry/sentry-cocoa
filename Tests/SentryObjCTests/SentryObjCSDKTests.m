@import SentryObjC;
@import XCTest;

#import <TargetConditionals.h>

@interface SentryObjCSDKTests : XCTestCase
@end

@implementation SentryObjCSDKTests

- (NSArray<NSDictionary<NSString *, id> *> *)currentFeatureFlagValues
{
    __block NSArray<NSDictionary<NSString *, id> *> *values = nil;
    [SentryObjCSDK configureScope:^(SentryObjCScope *scope) {
        NSDictionary<NSString *, id> *context = [scope serialize][@"context"];
        NSDictionary<NSString *, id> *flags = context[@"flags"];
        values = flags[@"values"];
    }];
    return values;
}

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

- (void)testStartWithOptions_shouldSetObjCSdkNameOnEvent
{
    // -- Arrange --
    [SentryObjCSDK close];
    __block NSDictionary<NSString *, id> *capturedSdk = nil;

    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.dsn = @"https://key@sentry.io/123";
    options.enableCrashHandler = NO;
    options.beforeSend = ^SentryObjCEvent *_Nullable(SentryObjCEvent *event)
    {
        capturedSdk = event.sdk;
        return event;
    };

    // -- Act --
    [SentryObjCSDK startWithOptions:options];
    [SentryObjCSDK captureEvent:[[SentryObjCEvent alloc] init]];

    // -- Assert --
    XCTAssertEqualObjects(capturedSdk[@"name"], @"sentry.cocoa.objc");
}

- (void)testStartWithConfigureOptions_shouldSetObjCSdkNameOnEvent
{
    // -- Arrange --
    [SentryObjCSDK close];
    __block NSDictionary<NSString *, id> *capturedSdk = nil;

    // -- Act --
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.beforeSend = ^SentryObjCEvent *_Nullable(SentryObjCEvent *event)
        {
            capturedSdk = event.sdk;
            return event;
        };
    }];
    [SentryObjCSDK captureEvent:[[SentryObjCEvent alloc] init]];

    // -- Assert --
    XCTAssertEqualObjects(capturedSdk[@"name"], @"sentry.cocoa.objc");
}

- (void)testClose_shouldRestoreBaseSdkName
{
    // -- Act --
    [SentryObjCSDK close];

    // -- Assert --
    XCTAssertEqualObjects([SentryObjCPrivateSDKOnly getSdkName], @"sentry.cocoa");
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

- (void)testMetrics_shouldReturnMetricsApi
{
    // -- Arrange & Act --
    SentryObjCMetricsApi *metrics = SentryObjCSDK.metrics;

    // -- Assert --
    XCTAssertNotNil(metrics);
}

#pragma mark - Capture Event

- (void)testCaptureEvent_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureEventWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureEventWithScopeBlock_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    __block BOOL blockCalled = NO;

    // -- Act --
    SentryObjCId *result =
        [SentryObjCSDK captureEvent:event
                     withScopeBlock:^(SentryObjCScope *scope) { blockCalled = YES; }];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
    XCTAssertTrue(blockCalled);
}

- (void)testCaptureEventAttachAllThreads_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureEvent:event attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

#pragma mark - Transactions

- (void)testStartTransaction_shouldReturnSpanWithCorrectOperation
{
    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithName:@"test" operation:@"op"];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionBindToScope_shouldReturnSpanWithCorrectOperation
{
    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithName:@"test"
                                                         operation:@"op"
                                                       bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContext_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContextBindToScope_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *ctx = [[SentryObjCTransactionContext alloc] initWithName:@"test"
                                                                                 operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK startTransactionWithContext:ctx bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)
    testStartTransactionWithContextBindToScopeCustomSampling_shouldReturnSpanWithCorrectOperation
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
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContextCustomSampling_shouldReturnSpanWithCorrectOperation
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
    XCTAssertEqualObjects(span.operation, @"op");
}

#pragma mark - Capture Error

- (void)testCaptureError_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureErrorWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureErrorWithScopeBlock_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    __block BOOL blockCalled = NO;

    // -- Act --
    SentryObjCId *result =
        [SentryObjCSDK captureError:error
                     withScopeBlock:^(SentryObjCScope *scope) { blockCalled = YES; }];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
    XCTAssertTrue(blockCalled);
}

- (void)testCaptureErrorAttachAllThreads_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureError:error attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

#pragma mark - Capture Exception

- (void)testCaptureException_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureExceptionWithScope_shouldReturnNonEmptyId
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
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureExceptionWithScopeBlock_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];
    __block BOOL blockCalled = NO;

    // -- Act --
    SentryObjCId *result =
        [SentryObjCSDK captureException:exception
                         withScopeBlock:^(SentryObjCScope *scope) { blockCalled = YES; }];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
    XCTAssertTrue(blockCalled);
}

- (void)testCaptureExceptionAttachAllThreads_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureException:exception attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

#pragma mark - Capture Message

- (void)testCaptureMessage_shouldReturnNonEmptyId
{
    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello"];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureMessageWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello" withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
}

- (void)testCaptureMessageWithScopeBlock_shouldReturnNonEmptyId
{
    // -- Arrange --
    __block BOOL blockCalled = NO;

    // -- Act --
    SentryObjCId *result =
        [SentryObjCSDK captureMessage:@"hello"
                       withScopeBlock:^(SentryObjCScope *scope) { blockCalled = YES; }];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
    XCTAssertTrue(blockCalled);
}

- (void)testCaptureMessageAttachAllThreads_shouldReturnNonEmptyId
{
    // -- Act --
    SentryObjCId *result = [SentryObjCSDK captureMessage:@"hello" attachAllThreads:YES];

    // -- Assert --
    XCTAssertNotNil(result);
    XCTAssertEqual(result.sentryIdString.length, 32U);
    XCTAssertFalse([result.sentryIdString isEqualToString:SentryObjCId.empty.sentryIdString]);
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

#pragma mark - Feature Flags

- (void)testAddFeatureFlagWithName_shouldPersistOnCurrentScope
{
    // -- Act --
    [SentryObjCSDK addFeatureFlagWithName:@"checkout" result:YES];

    // -- Assert --
    NSArray<NSDictionary<NSString *, id> *> *values = [self currentFeatureFlagValues];
    XCTAssertEqual(values.count, 1U);
    XCTAssertEqualObjects(values[0][@"flag"], @"checkout");
    XCTAssertEqualObjects(values[0][@"result"], @YES);
}

- (void)testRemoveFeatureFlagWithName_shouldRemoveFromCurrentScope
{
    // -- Arrange --
    [SentryObjCSDK addFeatureFlagWithName:@"checkout" result:YES];

    // -- Act --
    [SentryObjCSDK removeFeatureFlagWithName:@"checkout"];

    // -- Assert --
    XCTAssertNil([self currentFeatureFlagValues]);
}

#pragma mark - Configure Scope

- (void)testConfigureScope_shouldPersistTagOnScope
{
    // -- Arrange --
    [SentryObjCSDK configureScope:^(
        SentryObjCScope *scope) { [scope setTagValue:@"test-value" forKey:@"test-key"]; }];

    // -- Act --
    __block NSDictionary *capturedTags;
    [SentryObjCSDK configureScope:^(SentryObjCScope *scope) { capturedTags = scope.tags; }];

    // -- Assert --
    XCTAssertEqualObjects(capturedTags[@"test-key"], @"test-value");
}

#pragma mark - Crash Status

#if !SDK_V10
- (void)testCrashedLastRun_shouldReturnValidBool
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Arrange & Act --
    BOOL crashed = SentryObjCSDK.crashedLastRun;

    // -- Assert --
    XCTAssertTrue(crashed || !crashed);
#    pragma clang diagnostic pop
}
#endif

- (void)testLastRunStatus_shouldReturnValidStatus
{
    // -- Arrange & Act --
    SentryObjCLastRunStatus status = SentryObjCSDK.lastRunStatus;

    // -- Assert --
    // Just verify property access doesn't crash; value depends on runtime state.
    XCTAssertTrue(status == SentryObjCLastRunStatusUnknown
        || status == SentryObjCLastRunStatusDidCrash
        || status == SentryObjCLastRunStatusDidNotCrash);
}

- (void)testDetectedStartUpCrash_shouldReturnValidBool
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

#pragma mark - Extended App Start

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
- (void)testExtendAppStart_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK extendAppStart];
}

- (void)testGetExtendedAppStartSpan_withoutExtending_shouldReturnNil
{
    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK getExtendedAppStartSpan];

    // -- Assert --
    XCTAssertNil(span);
}

- (void)testGetExtendedAppStartSpan_afterExtending_shouldReturnSpan
{
    // -- Arrange --
    [SentryObjCSDK extendAppStart];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK getExtendedAppStartSpan];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertFalse(span.isFinished);
}

- (void)testFinishExtendedAppStart_withoutExtending_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK finishExtendedAppStart];
}

- (void)testFinishExtendedAppStart_afterExtending_shouldFinishSpan
{
    // -- Arrange --
    [SentryObjCSDK extendAppStart];
    SentryObjCSpan *span = [SentryObjCSDK getExtendedAppStartSpan];
    XCTAssertNotNil(span);

    // -- Act --
    [SentryObjCSDK finishExtendedAppStart];

    // -- Assert --
    XCTAssertTrue(span.isFinished);
}

- (void)testFinishExtendedAppStart_calledTwice_shouldNotCrash
{
    // -- Arrange --
    [SentryObjCSDK extendAppStart];

    // -- Act & Assert (no crash) --
    [SentryObjCSDK finishExtendedAppStart];
    [SentryObjCSDK finishExtendedAppStart];
}

- (void)testGetExtendedAppStartSpan_afterFinish_shouldReturnNil
{
    // -- Arrange --
    [SentryObjCSDK extendAppStart];
    [SentryObjCSDK finishExtendedAppStart];

    // -- Act --
    SentryObjCSpan *span = [SentryObjCSDK getExtendedAppStartSpan];

    // -- Assert --
    XCTAssertNil(span);
}
#endif

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
